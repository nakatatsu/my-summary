# Benchmark Result 2026-03

## スコアサマリー

| タスク | Claude Code | Codex |
|--------|------------|-------|
| タスク2（自動評価） | 3/4 | 3/4 |
| タスク1・3 | (相互評価参照) | (相互評価参照) |

A=claude, B=codex（評価時のブラインド割り当て）

---

## 設計

### Claude Code の成果物

## 1. ディレクトリ構成

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── stg/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── backend.tf
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecs/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── rds/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── README.md
```

---

## 2. モジュール分割方針

| モジュール | 責務 |
|---|---|
| **networking** | VPC、サブネット（public / private / isolated）、IGW、NAT Gateway、ルートテーブル、共通セキュリティグループ |
| **alb** | ALB本体、リスナー（HTTP→HTTPS リダイレクト、HTTPS）、ターゲットグループ、ALB用セキュリティグループ |
| **ecs** | ECSクラスタ、タスク定義、Fargateサービス、IAMロール（タスク実行/タスク）、ECS用セキュリティグループ、CloudWatch Logsロググループ |
| **rds** | RDSインスタンス（PostgreSQL）、サブネットグループ、パラメータグループ、RDS用セキュリティグループ |

**分割の原則**: 各層のライフサイクルと変更頻度に基づいて分離。networking は基盤として安定、ecs はデプロイ頻度が高く、rds はスキーマ変更を伴うため慎重な管理が必要。

---

## 3. 主要な変数・出力値の定義

### modules/networking

```hcl
# variables.tf
variable "project" {
  type        = string
  description = "プロジェクト名（リソース命名に使用）"
}

variable "environment" {
  type        = string
  description = "環境名（dev / stg / prod）"
}

variable "vpc_cidr" {
  type        = string
  description = "VPCのCIDRブロック"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "使用するAZ一覧"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "パブリックサブネットのCIDR一覧（ALB配置用）"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "プライベートサブネットのCIDR一覧（ECS配置用）"
}

variable "isolated_subnet_cidrs" {
  type        = list(string)
  description = "隔離サブネットのCIDR一覧（RDS配置用、NAT Gatewayなし）"
}
```

```hcl
# outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  value = aws_subnet.isolated[*].id
}
```

### modules/alb

```hcl
# variables.tf
variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "ALBを配置するVPCのID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "ALBを配置するパブリックサブネット"
}

variable "certificate_arn" {
  type        = string
  description = "ACM証明書のARN（HTTPS用）"
}

variable "health_check_path" {
  type        = string
  description = "ヘルスチェックパス"
  default     = "/health"
}
```

```hcl
# outputs.tf
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}
```

### modules/ecs

```hcl
# variables.tf
variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Fargateタスクを配置するプライベートサブネット"
}

variable "target_group_arn" {
  type        = string
  description = "ALBターゲットグループのARN"
}

variable "alb_security_group_id" {
  type        = string
  description = "ALBのSG ID（インバウンド許可元）"
}

variable "container_image" {
  type        = string
  description = "コンテナイメージURI"
}

variable "container_port" {
  type        = number
  description = "コンテナのリッスンポート"
  default     = 8080
}

variable "cpu" {
  type        = number
  description = "タスクCPUユニット"
  default     = 256
}

variable "memory" {
  type        = number
  description = "タスクメモリ（MiB）"
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "タスクの希望数"
  default     = 2
}

variable "db_endpoint" {
  type        = string
  description = "RDSエンドポイント（環境変数としてコンテナに渡す）"
}

variable "db_name" {
  type = string
}
```

```hcl
# outputs.tf
output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.main.name
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}
```

### modules/rds

```hcl
# variables.tf
variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "isolated_subnet_ids" {
  type        = list(string)
  description = "RDSを配置する隔離サブネット"
}

variable "ecs_security_group_id" {
  type        = string
  description = "ECSのSG ID（インバウンド許可元）"
}

variable "engine_version" {
  type        = string
  description = "PostgreSQLバージョン"
  default     = "16.4"
}

variable "instance_class" {
  type        = string
  description = "DBインスタンスクラス"
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  default     = 20
}

variable "db_name" {
  type        = string
  description = "初期データベース名"
}

variable "multi_az" {
  type        = bool
  description = "Multi-AZ配置の有効化"
  default     = false
}

variable "deletion_protection" {
  type        = bool
  default     = false
}
```

```hcl
# outputs.tf
output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_port" {
  value = aws_db_instance.main.port
}
```

### environments/dev/main.tf （モジュール呼び出し例）

```hcl
module "networking" {
  source = "../../modules/networking"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  isolated_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24"]
}

module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  certificate_arn   = var.certificate_arn
}

module "rds" {
  source = "../../modules/rds"

  project               = var.project
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  isolated_subnet_ids   = module.networking.isolated_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  db_name               = var.db_name
  multi_az              = false
}

module "ecs" {
  source = "../../modules/ecs"

  project               = var.project
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  container_image       = var.container_image
  db_endpoint           = module.rds.db_endpoint
  db_name               = module.rds.db_name
  desired_count         = 1
}
```

---

## 4. Terraformステート管理方針

### バックエンド構成

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "myproject-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "myproject-terraform-lock"
  }
}
```

| リソース | 設定 | 目的 |
|---|---|---|
| **S3バケット** | バージョニング有効、SSE-S3暗号化、パブリックアクセス全ブロック | ステートファイルの保存・履歴管理 |
| **DynamoDBテーブル** | パーティションキー `LockID`（String） | 排他ロックによる同時実行防止 |

### 環境分離戦略

```
S3バケット: myproject-terraform-state
├── dev/terraform.tfstate
├── stg/terraform.tfstate
└── prod/terraform.tfstate
```

- **1バケット・キープレフィックス分離方式**を採用。環境ごとにS3キーを分離し、単一バケットで管理する。
- 各環境の `terraform.tfvars` でインスタンスサイズやdesired_count等のパラメータを切り替える。
- prod環境のS3キーにはIAMポリシーで書き込み権限を制限し、CI/CDパイプライン経由のみ `apply` 可能とする。

### 環境別パラメータ差分の例

| パラメータ | dev | stg | prod |
|---|---|---|---|
| `instance_class` | db.t4g.micro | db.t4g.small | db.r7g.large |
| `multi_az` | false | false | true |
| `desired_count` | 1 | 2 | 4 |
| `deletion_protection` | false | false | true |
| `cpu` | 256 | 512 | 1024 |
| `memory` | 512 | 1024 | 2048 |


### Codex の成果物

**1. ディレクトリ構成（例）**
```text
terraform/
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecs_fargate/
│   │   ├── main.tf
│   │   ├── task_definition.tf
│   │   ├── service.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── rds_postgres/
│       ├── main.tf
│       ├── subnet_group.tf
│       ├── parameter_group.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   ├── stg/
│   │   └── (devと同構成)
│   └── prod/
│       └── (devと同構成)
└── versions.tf
```

**2. モジュール分割方針**

- `network`
  - VPC、Public/Privateサブネット、IGW/NAT、ルートテーブルを管理
  - 他モジュールへ `subnet_id` や `vpc_id` を提供
- `alb`
  - ALB本体、ターゲットグループ、リスナー（HTTP/HTTPS）、ALB用SGを管理
- `ecs_fargate`
  - ECS Cluster、Task Definition、Service、Auto Scaling、ECS用SGを管理
  - ALBターゲットグループへServiceを紐付け
- `rds_postgres`
  - RDS PostgreSQL、DB Subnet Group、Parameter Group、RDS用SGを管理
  - ECS SGからのDB接続のみ許可

**3. 主要な変数・出力値の定義（代表例）**

`modules/network/variables.tf`
```hcl
variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
```

`modules/network/outputs.tf`
```hcl
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
```

`modules/alb/variables.tf`
```hcl
variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "allowed_cidrs" { type = list(string) }
variable "certificate_arn" { type = string, default = null }
variable "target_port" { type = number, default = 80 }
```

`modules/alb/outputs.tf`
```hcl
output "alb_arn" { value = aws_lb.this.arn }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "alb_sg_id" { value = aws_security_group.alb.id }
```

`modules/ecs_fargate/variables.tf`
```hcl
variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "cluster_name" { type = string }
variable "container_image" { type = string }
variable "container_port" { type = number, default = 8080 }
variable "desired_count" { type = number, default = 2 }
variable "cpu" { type = number, default = 512 }
variable "memory" { type = number, default = 1024 }
variable "target_group_arn" { type = string }
variable "alb_sg_id" { type = string }
variable "db_endpoint" { type = string }
variable "db_secret_arn" { type = string }
```

`modules/ecs_fargate/outputs.tf`
```hcl
output "cluster_arn" { value = aws_ecs_cluster.this.arn }
output "service_name" { value = aws_ecs_service.this.name }
output "ecs_sg_id" { value = aws_security_group.ecs.id }
```

`modules/rds_postgres/variables.tf`
```hcl
variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }
variable "engine_version" { type = string, default = "16" }
variable "instance_class" { type = string, default = "db.t4g.medium" }
variable "allocated_storage" { type = number, default = 20 }
variable "db_name" { type = string }
variable "username" { type = string }
variable "manage_master_user_password" { type = bool, default = true }
```

`modules/rds_postgres/outputs.tf`
```hcl
output "db_instance_endpoint" { value = aws_db_instance.this.address }
output "db_instance_port" { value = aws_db_instance.this.port }
output "db_secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
```

**4. Terraformステート管理方針**

- バックエンド
  - `S3` にリモートステート保存（バージョニング有効、SSE-KMS暗号化）
  - `DynamoDB` でステートロック（同時更新防止）
- `backend.tf` 例
```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "3tier-webapp/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```
- 環境分離戦略
  - `environments/dev|stg|prod` を分離し、各環境で別 `key` を使用
  - 推奨は「環境ごとにAWSアカウント分離 + ステートキー分離」
  - `tfvars` を環境ごとに分け、CI/CDで `plan/apply` を環境単位で実行
  - `prod` は手動承認付きで apply を制御



### Claude Code による評価

### 成果物A 評価

- **正確性: ★2** / `environments/dev/main.tf`で`module.rds`が`module.ecs.ecs_security_group_id`を参照し、`module.ecs`が`module.rds.db_endpoint`を参照しており、**循環依存**が発生する。TerraformのDAG解決で`terraform plan`自体が失敗する致命的な設計欠陥。
- **安全性: ★3** / S3バケットのパブリックアクセスブロックやprod向けIAMポリシー制限は良いが、**RDSのパスワード管理戦略が完全に欠落**している。暗号化もSSE-S3でありKMSより弱い。
- **可読性: ★5** / モジュール責務表、環境別パラメータ差分表、変数への日本語`description`付与など、ドキュメントとしての完成度が非常に高い。isolated subnetの概念導入も意図が明確。
- **ベストプラクティス: ★3** / モジュール分離の方針（ライフサイクル・変更頻度基準）は優れるが、`versions.tf`・`providers.tf`が存在せずプロバイダバージョン固定がない。循環依存はTerraformの基本原則違反。
- **総合コメント:** ドキュメントの質は際立って高く、設計思想も明確。しかし、ECS⇔RDS間の循環依存は実装不可能な設計欠陥であり、SGを別モジュールに切り出す等の対応が必要。RDS認証情報の管理方針がないことも本番運用において重大な懸念。

---

### 成果物B 評価

- **正確性: ★4** / 循環依存がなく、モジュール間の依存関係が一方向に整理されている。`manage_master_user_password`によるSecrets Manager連携や`db_secret_arn`のECSへの受け渡しなど、実運用を意識した設計。ただしRDS用のisolatedサブネットがなくprivateサブネットにNAT経由のインターネット経路が残る点、変数定義のHCL構文（カンマ区切り）が非標準な点は軽微な減点要素。
- **安全性: ★4** / **SSE-KMS暗号化**、**Secrets Managerによるパスワード自動管理**、環境ごとの**AWSアカウント分離推奨**、prod手動承認など、セキュリティ設計が体系的。`certificate_arn`がデフォルト`null`でHTTPSが任意になる点は注意が必要。
- **可読性: ★3** / モジュール内のファイル粒度が細かく（`task_definition.tf`、`subnet_group.tf`等）コードの見通しが良い。一方、変数に`description`がほぼなく、ドキュメント全体の説明も簡素で、設計意図の伝達力はAに劣る。
- **ベストプラクティス: ★4** / `versions.tf`でバージョン固定、`providers.tf`でプロバイダ分離、`this`命名規則の採用、`manage_master_user_password`など**モダンなTerraformプラクティス**に準拠。アカウント分離戦略の推奨も適切。
- **総合コメント:** 技術的な正確性とセキュリティ設計に優れ、実装としてそのまま動作する可能性が高い。ドキュメント面での不足を補えば、本番運用に耐えうる設計。

---

### 最終判定

**成果物Bが総合的に優れている。**

| 評価軸 | A | B |
|---|---|---|
| 正確性 | ★2 | ★4 |
| 安全性 | ★3 | ★4 |
| 可読性 | ★5 | ★3 |
| ベストプラクティス | ★3 | ★4 |
| **合計** | **13** | **15** |

最大の差は**正確性**。Aの循環依存（ECS→RDS→ECS）はTerraformが構造的に許容しない設計であり、このままでは`terraform plan`すら通らない。IaCの成果物として「実際に適用可能か」は最重要基準であり、ここでAは大きく減点される。

Bは**Secrets Managerによるパスワード管理**、**SSE-KMS**、**アカウント分離の推奨**など、セキュリティ面でも一段上の設計を示している。`versions.tf`や`providers.tf`の存在もTerraformのベストプラクティスに沿う。

ただし、**Aの可読性・ドキュメント品質は突出しており**、設計書としての伝達力ではAが明確に勝る。循環依存の解消（SGモジュールの分離等）とRDS認証管理の追加を行えば、Aは非常に完成度の高い成果物になるポテンシャルを持つ。


### Codex による評価

### 成果物A 評価
- 正確性: ★2 / `environments/dev/main.tf` の `module "rds"` が `module.ecs.ecs_security_group_id` を参照し、同時に `module "ecs"` が `module.rds.db_endpoint` を参照しており、モジュール間の循環依存になります。これはそのままでは `plan`/`apply` できません。  
- 安全性: ★3 / ステートのS3暗号化・ロック方針はある一方、DB資格情報の扱い（Secrets Manager等）が設計に明示されておらず、`deletion_protection=false` のデフォルトも本番運用では弱いです。  
- 可読性: ★4 / 構成・責務分割・変数説明は丁寧で、初見でも追いやすいです。環境差分表も実運用を想像しやすいです。  
- ベストプラクティス: ★3 / モジュール分割やremote state方針は良いですが、循環依存の設計ミスが大きく、`versions.tf/providers.tf` の明示や機密情報設計も弱めです。  
- 総合コメント: 設計意図は良く、ドキュメント品質も高いですが、循環依存が致命的で実装としての完成度を下げています。

### 成果物B 評価
- 正確性: ★4 / 3層構成として必要な要素（network/alb/ecs/rds）を押さえ、依存方向も自然です。細部実装は未提示ですが、構造上は成立しやすい設計です。  
- 安全性: ★4 / `manage_master_user_password=true` と `db_secret_arn` 受け渡しは機密情報管理として良いです。加えてSSE-KMS前提のステート管理やprod承認フローも妥当です。  
- 可読性: ★4 / モジュール名と責務が明確で、`providers.tf`/`versions.tf` を環境構成に含めている点も理解しやすいです。  
- ベストプラクティス: ★4 / 状態管理、環境分離、Secrets連携、ECSモジュール分割（task/service分離）など、Terraform運用の実践に近いです。さらに `sensitive` 属性や入力バリデーションがあるとより良いです。  
- 総合コメント: 実運用寄りの設計で、特にセキュリティと運用面の配慮がAより一段良いです。

### 最終判定
**Bが総合的に優れています。**  
最大の理由は、Aにある循環依存の致命的な正確性問題がBには見られず、BはSecrets管理・state暗号化・運用統制まで含めて実装可能性が高い構成だからです。

---

## コード生成

### Claude Code の成果物

```hcl:versions.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

```hcl:variables.tf
variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones (exactly 2)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

```hcl:main.tf
################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
  })
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

################################################################################
# Public Subnets
################################################################################

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${var.azs[count.index]}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

################################################################################
# NAT Gateway (single, cost-optimized)
################################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat"
  })

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Private Subnets
################################################################################

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${var.azs[count.index]}"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt"
  })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

```hcl:outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.this.id
}
```

**構成のポイント:**

- **NAT Gateway 1個**: `aws_subnet.public[0]` に配置。AZごとに1個ずつ置くHA構成ではなく、コスト優先で1個に集約
- **ルートテーブル**: パブリック用（IGW向き）とプライベート用（NAT向き）を分離。プライベートは共通1テーブルで2サブネットを関連付け
- **タグ**: 全リソースで `merge(var.tags, { Name = "..." })` を使用し、呼び出し側から一括タグ付与可能


### Codex の成果物

```hcl:main.tf
locals {
  public_subnets = {
    for i, cidr in var.public_subnet_cidrs : i => {
      cidr = cidr
      az   = var.azs[i]
    }
  }

  private_subnets = {
    for i, cidr in var.private_subnet_cidrs : i => {
      cidr = cidr
      az   = var.azs[i]
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.value.az}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.value.az}"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["0"].id

  tags = merge(var.tags, {
    Name = "${var.name}-natgw"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt"
  })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
```

```hcl:variables.tf
variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Exactly 2 Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "azs must contain exactly 2 AZs."
  }
}

variable "public_subnet_cidrs" {
  description = "Exactly 2 CIDR blocks for public subnets."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must contain exactly 2 CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  description = "Exactly 2 CIDR blocks for private subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "private_subnet_cidrs must contain exactly 2 CIDR blocks."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
```

```hcl:outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [for s in aws_subnet.private : s.id]
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.this.id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID"
  value       = aws_route_table.private.id
}
```

```hcl:versions.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Claude Code による評価

### 成果物A 評価

- **正確性: ★4** / 技術的に正しく動作するVPCモジュールだが、`count = 2`がハードコードされており、変数のリスト長が不一致でも実行時までエラーが出ない。入力バリデーションがない。
- **安全性: ★3** / 基本的なVPC構成として問題ないが、VPCフローログやNACLの設定がない。`map_public_ip_on_launch = true`は意図的だが明示的なコメントがあるとなお良い。
- **可読性: ★4** / `################################################################################`によるセクション分けが明確で、`count`ベースのシンプルな構造は直感的に理解しやすい。構成ポイントの補足説明も丁寧。
- **ベストプラクティス: ★3** / `count`は要素の追加・削除時にインデックスずれによるリソース再作成のリスクがある。プロバイダ制約`>= 5.0`はメジャーバージョンアップ（仮に6.x）時に破壊的変更を許容してしまう。CIDR変数にデフォルト値があるのはIP競合の原因になりうる。
- **総合コメント:** 読みやすく堅実な構成で、小規模プロジェクトや学習用途には十分。ただし再利用可能なモジュールとしては、入力バリデーション不在と`count`利用がネックとなる。

---

### 成果物B 評価

- **正確性: ★4** / `validation`ブロックでAZ数・CIDR数を厳密に検証しており、誤入力を`plan`前に防止できる。ただし`for_each`のキーがインデックス文字列（`"0"`, `"1"`）であり、AZ名をキーにした方がより堅牢。
- **安全性: ★3** / Aと同等のセキュリティ水準。フローログやNACLはないが、基本的なVPCモジュールとしては許容範囲。`Tier`タグによるサブネット分類は運用時のセキュリティポリシー適用に有用。
- **可読性: ★4** / `locals`ブロックによるデータ変換は若干の抽象化レイヤーを追加するが、`for_each`パターンに慣れたTerformユーザーには自然。セクションコメントがない分、Aよりやや構造の把握に時間がかかる。
- **ベストプラクティス: ★4** / `for_each`の採用、`~> 5.0`によるメジャーバージョン固定、`validation`ブロック、`Tier`タグ付与、ルートテーブルIDのoutput公開など、モジュール設計として一段上。CIDRのデフォルト値を排除し明示的な入力を強制する設計も適切。
- **総合コメント:** 再利用可能なモジュールとして実践的な設計。バリデーション、`for_each`、適切なプロバイダ制約など、Terraformの推奨パターンに沿っている。`for_each`キーをAZ名にすればさらに良い。

---

### 最終判定

**成果物Bが総合的に優れている。**

主な差分は以下の3点:

1. **`for_each` vs `count`**: Bの`for_each`はリソースの安定性が高く、要素の追加・削除時に意図しない再作成が起きにくい（Terraformの公式でも`for_each`推奨）
2. **入力バリデーション**: Bは`validation`ブロックで不正入力を`terraform plan`前に検出できる。Aはランタイムエラーまで気づけない
3. **プロバイダ制約**: Bの`~> 5.0`はメジャーバージョン境界を守り、Aの`>= 5.0`より安全

一方、Aはセクションコメントによる可読性の高さと、補足説明の丁寧さが光る。初学者やドキュメント重視のチームには好まれるスタイルである。実運用モジュールとしてはBを採用し、Aのコメントスタイルを取り入れると理想的な成果物になる。


### Codex による評価

### 成果物A 評価
- 正確性: ★3 / VPC・IGW・Public/Private subnet・NAT・ルート関連の基本構成は成立しています。  
  ただし `count = 2` 前提なのに `azs` や CIDR リスト長の `validation` がなく、入力不整合時に壊れやすいです。
- 安全性: ★3 / 明確な危険設定は少ない一方、Public Subnet の自動 Public IP 付与や 0.0.0.0/0 ルートは設計上の露出を伴います。  
  さらに単一 NAT は障害時に Private 側通信が止まるため可用性・運用安全面で弱いです。
- 可読性: ★4 / セクション分割と命名が素直で、初見でも追いやすい構成です。  
  `count.index` ベースで意図は明確ですが、入力制約がコード上で表現されていない点は読み手に負担です。
- ベストプラクティス: ★3 / タグ統合や基本的な分割は良いですが、`count` 固定2本・変数検証なし・バージョン制約が広すぎる点が減点です。  
  モジュール利用時の堅牢性（バリデーション・将来拡張性）はやや不足しています。
- 総合コメント: 実装はシンプルで実用的ですが、「2AZ前提」の暗黙依存を明示的に縛っていないため、運用での事故耐性が低めです。

### 成果物B 評価
- 正確性: ★4 / Aと同等のネットワーク要件を満たしつつ、`azs`/subnet CIDR の件数を `validation` で強制しており破綻しにくいです。  
  `for_each` とローカル値でサブネット定義を組み立てており、意図と実装が一致しています。
- 安全性: ★3 / セキュリティ強化（NACL/Flow Logs/厳格な経路制御）までは含まれず、単一 NAT も同様の可用性リスクがあります。  
  ただし入力検証がある分、誤設定による事故はAより起きにくいです。
- 可読性: ★4 / `locals` と `for_each` により重複が減り、構造が整理されています。  
  一方で `aws_subnet.public["0"]` の参照は少しトリッキーで、コメントがあるとより親切です。
- ベストプラクティス: ★4 / `for_each` 採用、変数検証、`~> 5.0` のプロバイダ制約はTerraform実務で好まれる書き方です。  
  さらにCIDR形式の検証やAZ/CIDRの整合チェックまであると★5に近づきます。
- 総合コメント: 実装の堅牢性と保守性がAより高く、同じ要件ならBのほうが実運用向きです。

### 最終判定
**総合的にBが優れています。**  
理由は、要件実装そのものは両者ほぼ同等でも、Bは `validation` と `for_each` により入力ミス耐性・変更耐性が高く、Terraformベストプラクティスへの適合度が高いためです。

---

## レビュー

### Claude Code の成果物

## Terraform コードレビュー結果

### セキュリティ

- **[CRITICAL]** `aws_security_group.web` ingress : 全ポート(0-65535)を全IPに開放している -> 必要なポート(例: 80, 443)のみに限定し、ソースIPも制限する
- **[CRITICAL]** `aws_db_instance.main.password` : パスワードがハードコードされている -> `aws_secretsmanager_secret` または `variable` + `sensitive = true` で管理する。tfstateにも平文で残る
- **[CRITICAL]** `aws_db_instance.main.publicly_accessible` : RDSがパブリックアクセス可能 -> `publicly_accessible = false` にしてプライベートサブネットに配置する
- **[HIGH]** `aws_db_instance.main.storage_encrypted` : ストレージ暗号化が無効 -> `storage_encrypted = true` + `kms_key_id` を指定する
- **[HIGH]** `aws_s3_bucket.data` : バケットのパブリックアクセス制御がない -> `aws_s3_bucket_public_access_block` で全パブリックアクセスをブロックする
- **[HIGH]** `aws_s3_bucket.data` : サーバーサイド暗号化が未設定 -> `aws_s3_bucket_server_side_encryption_configuration` で SSE-S3 または SSE-KMS を設定する
- **[HIGH]** `aws_s3_bucket.data` : バージョニングが未設定 -> `aws_s3_bucket_versioning` を有効にして誤削除・改ざんに備える
- **[MEDIUM]** `aws_db_instance.main.skip_final_snapshot` : 最終スナップショットがスキップされる -> 本番では `skip_final_snapshot = false` + `final_snapshot_identifier` を指定する
- **[MEDIUM]** `aws_db_instance.main` : `backup_retention_period` が未設定(デフォルト0) -> 最低7日以上に設定する
- **[MEDIUM]** `aws_db_instance.main` : `multi_az` が未設定 -> 本番では `multi_az = true` で可用性を確保する
- **[MEDIUM]** `aws_db_instance.main` : `deletion_protection` が未設定 -> `deletion_protection = true` で誤削除を防止する
- **[MEDIUM]** `aws_db_instance.main` : `db_subnet_group_name` が未指定 -> 専用のプライベートサブネットグループを作成して指定する
- **[MEDIUM]** `aws_db_instance.main.username` : 管理者ユーザー名が `admin` -> 推測されにくい名前に変更する
- **[LOW]** `provider "aws"` : `default_tags` が未設定 -> 環境名・プロジェクト名等のタグを付与してコスト管理・運用を容易にする
- **[LOW]** `aws_s3_bucket.data` : バケット名がグローバルで予測可能 -> プレフィックスにアカウントIDやランダム文字列を含める
- **[LOW]** 全体 : `terraform` ブロックで `required_version` / `required_providers` が未定義 -> バージョンを固定して再現性を確保する

---

### 最優先で直すべき TOP3

| 優先度 | 対象 | 理由 |
|---|---|---|
| **1** | RDSパスワードのハードコード | tfstateに平文保存され、VCS履歴にも残る。Secrets ManagerまたはSSM Parameter Storeで管理すべき |
| **2** | RDSのパブリックアクセス有効 | インターネットからDBに直接到達可能。全ポート開放のSGと合わせてDB侵害リスクが極めて高い |
| **3** | SGの全ポート全IP開放 | 攻撃対象面が最大化されている。最小権限の原則に従いポートとソースを限定すべき |


### Codex の成果物

- [CRITICAL] `aws_security_group.web.ingress` : `0.0.0.0/0` に対して TCP `0-65535` を全開放しており外部から任意ポートに到達可能 -> 必要最小ポートのみを許可し、送信元 CIDR も限定（例: ALB/社内IP のみ）
- [CRITICAL] `aws_db_instance.main.password` : DBパスワードを平文ハードコードしており漏洩リスクが高い -> `sensitive` な変数 + Secrets Manager/SSM Parameter Store 参照に変更し、コードに秘匿情報を置かない
- [HIGH] `aws_db_instance.main.publicly_accessible` : RDS がインターネット公開される設定 -> `false` にしてプライベートサブネット配置、接続元をDB用Security Groupで制限
- [HIGH] `aws_db_instance.main.storage_encrypted` : ストレージ暗号化が無効で機密データ保護要件に違反しやすい -> `storage_encrypted = true` とし必要ならKMSキーを明示
- [HIGH] `aws_db_instance.main` : `db_subnet_group_name` と `vpc_security_group_ids` 未指定でネットワーク境界が不明確 -> 専用DBサブネットグループと最小権限SGを明示設定
- [MEDIUM] `aws_db_instance.main.skip_final_snapshot` : 削除時に最終スナップショットを取らず復旧不能リスク -> `skip_final_snapshot = false` にして `final_snapshot_identifier` を設定
- [MEDIUM] `aws_s3_bucket.data` : バケット暗号化設定がなく保存データが平文になり得る -> `server_side_encryption_configuration`（SSE-S3 or SSE-KMS）を有効化
- [MEDIUM] `aws_s3_bucket.data` : パブリックアクセス遮断設定がなく誤公開事故の余地 -> `aws_s3_bucket_public_access_block` を追加し4項目すべて `true`
- [MEDIUM] `aws_s3_bucket.data` : バージョニング未設定で誤削除・ランサム時の耐性不足 -> `aws_s3_bucket_versioning` を有効化
- [LOW] `aws_s3_bucket.data.bucket` : グローバル一意名を固定文字列で指定しており作成失敗/衝突しやすい -> 環境名・アカウントID・ランダムsuffixを含む命名へ変更
- [LOW] 全リソース共通 : `tags` がなく運用管理（課金、棚卸し、監査）が困難 -> 共通タグ（`Environment`, `Owner`, `CostCenter` など）を付与

最優先で直すべきTOP3  
1. `aws_security_group.web.ingress` の全ポート全開放を即時停止（最小ポート・最小CIDR化）  
2. `aws_db_instance.main.password` の平文ハードコードを廃止（Secrets Manager/SSM化）  
3. `aws_db_instance.main` の公開設定と暗号化を是正（`publicly_accessible=false`, `storage_encrypted=true`）

### Claude Code による評価

## 成果物A 評価

- **正確性: ★5** / 検出項目が15件と網羅的で、`backup_retention_period`、`multi_az`、`deletion_protection`、`required_version`/`required_providers` など運用・再現性に関わる項目まで漏れなく指摘している。重要度の分類も妥当。
- **安全性: ★5** / CRITICAL 3件・HIGH 4件・MEDIUM 5件と多層的にリスクを捕捉しており、`admin`ユーザー名の推測リスクやtfstateへの平文保存まで言及している点が実務的に優れている。
- **可読性: ★5** / 「セキュリティ」セクション見出し、`[SEVERITY] resource.path : 問題 -> 対策` の統一フォーマット、TOP3のMarkdownテーブルなど、構造が明確で一覧性が高い。
- **ベストプラクティス: ★5** / `required_version`/`required_providers`によるバージョン固定、`default_tags`、KMS指定、DBサブネットグループ作成など、Terraformの運用ベストプラクティスを広くカバーしている。
- **総合コメント:** 検出の網羅性・構造化・具体的な改善指示のいずれも高水準。本番運用に向けたレビューとしてそのまま使える品質。

---

## 成果物B 評価

- **正確性: ★3** / 主要な問題は正しく検出しているが、全10件にとどまり、`backup_retention_period`、`multi_az`、`deletion_protection`、`required_version`、`admin`ユーザー名などの指摘が欠落している。TOP3の3番目で`publicly_accessible`と`storage_encrypted`を1項目に統合しており、個別の改善アクションが不明瞭。
- **安全性: ★4** / CRITICAL・HIGHレベルの主要リスクは的確に捕捉しており、「ランサム時の耐性不足」や「機密データ保護要件」への言及など実務的な視点もある。ただし`deletion_protection`やバックアップ保持期間の欠落は安全性レビューとして不足。
- **可読性: ★3** / フォーマットは統一されているが、セクション見出しがなく全項目がフラットに並んでいるため、一覧時の把握が難しい。TOP3も番号付きリストのみで、テーブル形式のAと比べ構造化が弱い。
- **ベストプラクティス: ★3** / タグ付与やサブネットグループの指摘はあるが、`required_version`/`required_providers`のバージョン固定、`default_tags`、`multi_az` といったTerraform運用の定番プラクティスへの言及が不足している。
- **総合コメント:** コアとなるセキュリティリスクの検出は正確だが、網羅性と構造化に課題がある。ドラフトレビューとしては有用だが、本番向けには追加の深掘りが必要。

---

## 最終判定

**成果物Aが総合的に優れている。**

| 評価軸 | 成果物A | 成果物B |
|---|---|---|
| 正確性 | ★5 | ★3 |
| 安全性 | ★5 | ★4 |
| 可読性 | ★5 | ★3 |
| ベストプラクティス | ★5 | ★3 |

決定的な差は**網羅性**にある。Aは15件の指摘でインフラの安全性・可用性・運用性を多層的にカバーしているのに対し、Bは10件にとどまり`deletion_protection`、`backup_retention_period`、`multi_az`、`required_version`といった本番運用で不可欠な項目が欠落している。また、Aはセクション構造・マークダウンテーブル・統一フォーマットにより、レビュー結果をそのままチームに共有・チケット化できる実用性を備えている。Bも主要リスクの検出は正確で「ランサム耐性」など独自の視点もあるが、IaCレビューとしての完成度ではAに及ばない。


### Codex による評価

### 成果物A 評価
- 正確性: ★4 / 主要な指摘（SG全開放、RDS平文パスワード、RDS公開、暗号化不足など）は技術的に妥当です。  
  一方で `backup_retention_period` や `multi_az` を一律に問題化する点は、環境要件次第で過剰評価になり得ます。
- 安全性: ★5 / 重大リスクの優先順位付けが明確で、実際の侵害リスクに直結する項目を上位に置けています。  
  対応策も具体的で、即時是正につながる内容です。
- 可読性: ★4 / 見出し、重要度、TOP3の整理が分かりやすく、レビューとして読みやすい構成です。  
  ただし項目数が多く、要件依存の指摘が混ざっているため、実装者視点ではノイズも少しあります。
- ベストプラクティス: ★4 / `required_version`・`required_providers`・タグ方針などIaC運用面まで触れている点は良いです。  
  ただし本番前提の推奨（Multi-AZ等）が強めで、汎用テンプレートとしてはやや硬いです。
- 総合コメント: 網羅性とセキュリティ観点は非常に強く、監査寄りのレビューとして優秀です。要件依存の指摘を少し絞ると、さらに実践的になります。

### 成果物B 評価
- 正確性: ★5 / 重大項目を中心に、設定値とリスクの因果関係が明確で、技術的整合性が高いです。  
  「何をどう直すか」が具体的で、実装に直結します。
- 安全性: ★5 / 攻撃面の縮小（最小ポート/CIDR）、機密情報管理、DB非公開化、暗号化の4点を高優先で押さえており実効性が高いです。  
  運用事故（S3誤公開・誤削除）への備えもバランス良く含まれています。
- 可読性: ★5 / 箇条書きが簡潔で、各指摘が「問題→影響→修正案」で統一されていて理解しやすいです。  
  冗長さが少なく、レビュー消化が速い構成です。
- ベストプラクティス: ★4 / 最小権限、シークレット外部化、暗号化、タグ付けなど実務的ベストプラクティスを適切に反映しています。  
  ただしTerraform自体の再現性管理（`required_version`/`required_providers`）への言及は不足しています。
- 総合コメント: 実装者がすぐ修正に移れる品質で、精度と実用性のバランスが良いレビューです。網羅性はAよりやや薄いものの、優先順位の切り方が実践的です。

### 最終判定
**Bが総合的に優れています。**  
理由は、重要リスクへの集中度が高く、指摘の書き方が一貫していて実装修正に直結するためです。Aは網羅性で強みがありますが、要件依存の指摘が一部混ざり、実務での即応性はBのほうが高いです。

---
