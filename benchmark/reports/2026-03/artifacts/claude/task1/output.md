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
