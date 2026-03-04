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

