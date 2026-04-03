# Benchmark Result 2026-04

## スコアサマリー

| タスク | Claude Code | Codex |
|--------|------------|-------|
| タスク2（自動評価） | 2/4 | -/4 |
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
└── modules/
    ├── network/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecs/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## 2. モジュール分割方針

| モジュール | 責務 |
|---|---|
| **network** | VPC、サブネット（public/private/isolated）、IGW、NAT Gateway、ルートテーブル、共通セキュリティグループの基盤を提供 |
| **alb** | ALB本体、リスナー（HTTP→HTTPS リダイレクト、HTTPS）、ターゲットグループ、ALB用セキュリティグループ |
| **ecs** | ECSクラスター、タスク定義、Fargateサービス、IAMロール（タスク実行/タスク）、オートスケーリング、ECS用セキュリティグループ |
| **rds** | RDS PostgreSQLインスタンス、サブネットグループ、パラメータグループ、DB用セキュリティグループ |

**分割の原則**: ライフサイクルとオーナーシップが異なるリソースを分離する。networkは基盤として最も安定し、rdsはデータを持つため破壊的変更を避ける必要がある。albとecsはデプロイ頻度が高い。

**依存関係**:
```
network → alb → ecs
network → rds
```

## 3. 主要な変数・出力値の定義

### modules/network

```hcl
# variables.tf
variable "project" {
  type        = string
  description = "プロジェクト名（リソース命名に使用）"
}

variable "env" {
  type        = string
  description = "環境名（dev/stg/prod）"
}

variable "vpc_cidr" {
  type        = string
  description = "VPCのCIDRブロック"
  default     = "10.0.0.0/16"
}

variable "az_count" {
  type        = number
  description = "使用するAZの数"
  default     = 2
}
```

```hcl
# outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "ALB配置用"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "ECS Fargate配置用"
  value       = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  description = "RDS配置用（NAT Gatewayへのルートなし）"
  value       = aws_subnet.isolated[*].id
}
```

### modules/alb

```hcl
# variables.tf
variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {
  type        = string
  description = "ACM証明書のARN"
}

variable "health_check_path" {
  type    = string
  default = "/health"
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
  description = "ECSサービスに渡すターゲットグループ"
  value       = aws_lb_target_group.app.arn
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

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "container_image" {
  type        = string
  description = "ECRイメージURI（tag含む）"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "db_endpoint" {
  type        = string
  description = "RDSエンドポイント（環境変数として注入）"
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
  value = aws_ecs_service.app.name
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}
```

### modules/rds

```hcl
# variables.tf
variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "isolated_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type        = string
  description = "ECSからのインバウンドを許可するSG"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_name" {
  type    = string
  default = "app"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}
```

```hcl
# outputs.tf
output "endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_security_group_id" {
  value = aws_security_group.rds.id
}
```

### environments/dev/main.tf（モジュール呼び出し例）

```hcl
module "network" {
  source   = "../../modules/network"
  project  = var.project
  env      = var.env
  vpc_cidr = "10.0.0.0/16"
}

module "alb" {
  source            = "../../modules/alb"
  project           = var.project
  env               = var.env
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  certificate_arn   = var.certificate_arn
}

module "rds" {
  source                = "../../modules/rds"
  project               = var.project
  env                   = var.env
  vpc_id                = module.network.vpc_id
  isolated_subnet_ids   = module.network.isolated_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  instance_class        = "db.t4g.micro"
  multi_az              = false
  deletion_protection   = false
}

module "ecs" {
  source                = "../../modules/ecs"
  project               = var.project
  env                   = var.env
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  container_image       = var.container_image
  desired_count         = 1
  db_endpoint           = module.rds.endpoint
  db_name               = module.rds.db_name
}
```

## 4. Terraformステート管理方針

### バックエンド構成

各環境ごとに独立したステートファイルをS3に保存し、DynamoDBでロックする。

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

| 環境 | S3キー | 用途 |
|---|---|---|
| dev | `dev/terraform.tfstate` | 開発・検証 |
| stg | `stg/terraform.tfstate` | ステージング |
| prod | `prod/terraform.tfstate` | 本番 |

### 環境分離戦略

**方針: ディレクトリ分離 + 共通モジュール参照**

- **同一S3バケット・異なるキー**: バケットは1つに集約しつつ、`key`プレフィックスで環境を分離する。IAMポリシーでキープレフィックスごとにアクセス制御が可能。
- **DynamoDBロックテーブルは共有**: `LockID`パーティションキーにより、ステートファイル単位でロックが分離されるため1テーブルで十分。
- **環境差分は`terraform.tfvars`で吸収**: モジュールのコードは共通、パラメータ（インスタンスサイズ、desired_count、multi_az等）で環境差を表現する。

```
terraform.tfvars の環境差分例:

dev:   instance_class = "db.t4g.micro",  desired_count = 1, multi_az = false
stg:   instance_class = "db.t4g.small",  desired_count = 2, multi_az = false
prod:  instance_class = "db.r7g.large",  desired_count = 3, multi_az = true
```

### 前提となるブートストラップリソース

S3バケットとDynamoDBテーブルはTerraform管理外で事前作成する（またはブートストラップ用の別ステートで管理する）。

```hcl
# bootstrap/main.tf（参考）
resource "aws_s3_bucket" "tfstate" {
  bucket = "myproject-terraform-state"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_dynamodb_table" "tflock" {
  name         = "myproject-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
```


### Codex の成果物

(Codex 実行失敗: OPENAI_API_KEY 未設定のため出力なし)


### Claude Code による評価

成果物Bの内容が空です。メッセージが「## 成果物B」で終わっており、コードや文書が含まれていません。

成果物Bの内容を貼り付けていただければ、両方を比較評価します。


### Codex による評価

(Codex 評価未実施: OPENAI_API_KEY 未設定)


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
  description = "Name prefix for all resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of two availability zones"
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

  tags = merge(var.tags, { Name = var.name })
}

################################################################################
# Subnets
################################################################################

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${var.name}-public-${var.azs[count.index]}" })
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, { Name = "${var.name}-private-${var.azs[count.index]}" })
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = var.name })
}

################################################################################
# NAT Gateway (single, cost-optimized)
################################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, { Name = var.name })

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Route Tables - Public
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
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
# Route Tables - Private
################################################################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-private" })
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

**設計ポイント:**

- **NAT Gateway 1個**: `public[0]` にのみ配置し、プライベートサブネット2つで共有。コスト優先の要件を満たす（NAT Gatewayは1個あたり約$32/月）
- **ルートテーブル**: パブリック用（IGW向け）とプライベート用（NAT向け）を各1つ作成し、それぞれ2サブネットに関連付け
- **タグ**: 全リソースで `merge(var.tags, { Name = "..." })` を使用し、呼び出し側からの共通タグとリソース固有のNameタグを統合
- **`depends_on`**: NAT GatewayがIGW作成後に作られるよう明示（AWS公式推奨）


### Codex の成果物

(Codex 実行失敗: OPENAI_API_KEY 未設定のため出力なし)


### Claude Code による評価

### 成果物A 評価

- **正確性: ★4** / VPC・サブネット・IGW・NAT GW・ルートテーブルの構成は技術的に正しく、2AZ構成として機能する。ただし `count = 2` がハードコードされており、`length(var.azs)` や `length(var.public_subnet_cidrs)` を使うべき。AZを3つ渡した場合にサブネットが2つしか作られない不整合が起きる。
- **安全性: ★4** / プライベートサブネットはNAT経由のみで外部通信し、パブリックサブネットのみ `map_public_ip_on_launch = true` と適切に分離されている。VPC Flow Logsやデフォルトセキュリティグループの制限がないが、VPCモジュールの責務としては許容範囲。
- **可読性: ★5** / セクションごとにコメントヘッダで区切られ、ファイル分割（versions/variables/main/outputs）も標準的。変数名・リソース名ともに明快で、設計ポイントの説明も的確。
- **ベストプラクティス: ★4** / `merge(var.tags, ...)` によるタグ戦略、`depends_on` の明示、EIPの `domain = "vpc"` 指定など良好。改善点として、`count` より `for_each` の方がリソース削除時の影響範囲が小さく推奨される。また `required_version = ">= 1.0"` は範囲が広すぎ、`~> 1.x` のような制約が望ましい。
- **総合コメント:** 実用的で堅実なVPCモジュール。コスト最適化（NAT GW 1台）の判断も文書化されており、本番利用に十分耐えうる品質。`count` → `for_each` 化とバージョン制約の厳格化が次のステップ。

### 成果物B 評価

- **正確性: ★1** / 成果物が存在しない。要件を一切満たしていない。
- **安全性: ★1** / 評価対象なし。
- **可読性: ★1** / 評価対象なし。
- **ベストプラクティス: ★1** / 評価対象なし。
- **総合コメント:** APIキー未設定により実行自体が失敗しており、成果物として提出されていない。環境構築の段階で躓いている。

### 最終判定

**成果物Aが圧倒的に優れている。** 成果物Bは実行失敗により出力がゼロであり、比較以前の問題。成果物Aは細かな改善余地（`count` → `for_each`、バージョン制約の厳格化）はあるものの、正確で読みやすく、本番投入可能な品質のTerraformモジュールとなっている。


### Codex による評価

(Codex 評価未実施: OPENAI_API_KEY 未設定)


---

## レビュー

### Claude Code の成果物

## Terraformコードレビュー結果

### 全指摘事項

```
- [CRITICAL] aws_db_instance.main.password : パスワードがハードコード("password123")されている -> aws_secretsmanager_secretまたはvariable(sensitive=true)で管理し、terraform.tfstateへの平文記録も防止する
- [CRITICAL] aws_security_group.web.ingress : 全ポート(0-65535)を全IPに開放している -> 必要なポート(例:443,80)のみに限定し、CIDRも最小範囲に絞る
- [CRITICAL] aws_db_instance.main.publicly_accessible : RDSがインターネットに公開されている -> publicly_accessible=falseにしプライベートサブネットに配置する
- [HIGH] aws_db_instance.main.storage_encrypted : ストレージ暗号化が無効 -> storage_encrypted=trueに変更しKMSキーを指定する
- [HIGH] aws_db_instance.main : Multi-AZ未設定でSPOF -> multi_az=trueを設定し可用性を確保する
- [HIGH] aws_db_instance.main : backup_retention_periodが未設定(デフォルト0) -> 適切な保持期間(例:7日以上)を明示的に設定する
- [HIGH] aws_db_instance.main : deletion_protectionが未設定 -> deletion_protection=trueで誤削除を防止する
- [HIGH] aws_s3_bucket.data : バケットのサーバーサイド暗号化が未設定 -> aws_s3_bucket_server_side_encryption_configurationでAES256またはKMS暗号化を有効にする
- [HIGH] aws_s3_bucket.data : パブリックアクセスブロックが未設定 -> aws_s3_bucket_public_access_blockで全項目trueに設定する
- [HIGH] aws_s3_bucket.data : バケットバージョニングが未設定 -> aws_s3_bucket_versioningでEnabled設定にしデータ保護を強化する
- [MEDIUM] aws_s3_bucket.data : アクセスログが未設定 -> aws_s3_bucket_loggingでログバケットへの出力を設定する
- [MEDIUM] aws_db_instance.main.username : DB管理ユーザー名が"admin"で推測容易 -> より推測しにくいユーザー名を使用する
- [MEDIUM] provider "aws" : Terraformおよびプロバイダのバージョン制約がない -> required_providersブロックでバージョンを固定する
- [MEDIUM] aws_vpc.main : VPCにフローログが未設定 -> aws_flow_logを追加し通信を監査可能にする
- [LOW] 全リソース : タグが一切付与されていない -> 共通タグ(Environment, Project, ManagedBy等)をdefault_tagsまたは各リソースに付与する
- [LOW] aws_db_instance.main : engine_versionが未指定でメジャーバージョンアップの影響を受ける可能性あり -> 明示的にバージョンを固定する
- [LOW] aws_db_instance.main.skip_final_snapshot : 本番運用時にスナップショットなしで削除される -> 本番ではfalseに変更しfinal_snapshot_identifierを指定する
```

### 最優先で直すべきTOP3

| 優先度 | 対象 | 理由 |
|---|---|---|
| **1** | `aws_db_instance.main.password` ハードコード | tfstateに平文保存され、GitリポジトリにもDB認証情報が漏洩する。Secrets ManagerまたはSSM Parameter Store連携が必須 |
| **2** | `aws_security_group.web` 全ポート全開放 + `aws_db_instance.main.publicly_accessible=true` | RDSが公開状態かつSGが全開放のため、DB総当たり攻撃に直結する。この2つはセットで即時修正すべき |
| **3** | `aws_db_instance.main.storage_encrypted=false` + S3暗号化・パブリックアクセスブロック未設定 | 保存データが平文のまま保管され、コンプライアンス要件(個人情報保護法等)を満たせない |


### Codex の成果物

(Codex 実行失敗: OPENAI_API_KEY 未設定のため出力なし)


### Claude Code による評価

### 成果物A 評価

- **正確性: ★5** / パスワードハードコード、SG全開放、RDS公開設定など、Terraformにおける典型的かつ重大な問題を網羅的に検出しており、指摘内容も技術的に正確。
- **安全性: ★5** / CRITICAL/HIGH/MEDIUM/LOWの重大度分類が適切で、修正方針（Secrets Manager連携、暗号化、パブリックアクセスブロック等）も具体的かつ妥当。
- **可読性: ★4** / `[CRITICAL]`等のラベル付き一覧形式で一目で把握でき、TOP3の表形式も分かりやすい。ただし指摘数が多いため、カテゴリ別（ネットワーク/データ保護/運用等）にグルーピングするとさらに見通しが良くなる。
- **ベストプラクティス: ★5** / `required_providers`のバージョン固定、`default_tags`、VPCフローログ、S3バージョニングなど、AWSおよびTerraformのベストプラクティスに沿った指摘が揃っている。

- **総合コメント:** 実務レベルで即座に活用できる高品質なレビュー結果。指摘の粒度・網羅性・優先度付けのいずれも適切で、修正方針まで含まれている点が特に優れている。

---

### 成果物B 評価

- **正確性: ★1** / 出力が存在しないため、要件を一切満たしていない。
- **安全性: ★1** / 評価対象となるレビュー結果がない。
- **可読性: ★1** / エラーメッセージのみで成果物としての内容がない。
- **ベストプラクティス: ★1** / 評価不能。

- **総合コメント:** APIキー未設定による実行失敗で成果物が生成されていない。ツールの前提条件を満たせなかった時点で成果物として成立していない。

---

### 最終判定

**成果物Aが圧倒的に優れている。**

成果物Bは実行失敗により出力がゼロであり、比較の土台に立っていない。成果物Aは単独で見ても、重大度の分類・指摘の網羅性・修正方針の具体性が高水準であり、実務のセキュリティレビューとしてそのまま利用できる品質にある。


### Codex による評価

(Codex 評価未実施: OPENAI_API_KEY 未設定)


---
