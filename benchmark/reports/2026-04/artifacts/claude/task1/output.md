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
