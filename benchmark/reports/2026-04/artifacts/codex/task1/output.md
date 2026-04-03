以下は、AWS上に 3 層 Web アプリケーション `ALB + ECS(Fargate) + RDS(PostgreSQL)` を構築する前提の、実務向け Terraform モジュール構成案です。

**1. ディレクトリ構成**
```text
terraform/
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security_group/
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
│   ├── rds/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars
│   │   └── versions.tf
│   ├── stg/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars
│   │   └── versions.tf
│   └── prod/
│       ├── backend.tf
│       ├── main.tf
│       ├── providers.tf
│       ├── terraform.tfvars
│       └── versions.tf
└── bootstrap/
    ├── backend/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── README.md
```

**2. モジュール分割方針**
- `network`
  - VPC、パブリック/プライベートサブネット、Internet Gateway、NAT Gateway、Route Table を管理する。
  - 依存の基盤になるため、他モジュールから最も多く参照される。
- `security_group`
  - ALB、ECS、RDS 用の Security Group を一元管理する。
  - 通信要件を明示しやすくし、責務を分離する。
- `alb`
  - ALB 本体、Target Group、Listener、Listener Rule を管理する。
  - ECS サービスの入口として扱う。
- `ecs`
  - ECS Cluster、Task Definition、Service、CloudWatch Logs を管理する。
  - ALB Target Group と連携し、Fargate 上でアプリを実行する。
- `rds`
  - RDS PostgreSQL、DB Subnet Group、Parameter Group、Option Group を管理する。
  - DB の可用性・バックアップ・性能設定を責務とする。
- `iam`
  - ECS Task Execution Role、Task Role などを管理する。
  - 権限設計を独立させ、再利用しやすくする。

補足:
- `security_group` と `iam` を分けるのは、ネットワーク境界と権限境界を別管理にするためです。
- 小規模なら `iam` を `ecs` に内包してもよいですが、実務では分離した方が保守しやすいです。

**3. 主要な変数・出力値の定義**

`modules/network/variables.tf`
```hcl
variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}
```

`modules/network/outputs.tf`
```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  value = aws_subnet.private_db[*].id
}
```

`modules/security_group/variables.tf`
```hcl
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "db_port" {
  type    = number
  default = 5432
}
```

`modules/security_group/outputs.tf`
```hcl
output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}
```

`modules/alb/variables.tf`
```hcl
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}
```

`modules/alb/outputs.tf`
```hcl
output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}
```

`modules/iam/variables.tf`
```hcl
variable "name" {
  type = string
}
```

`modules/iam/outputs.tf`
```hcl
output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}
```

`modules/ecs/variables.tf`
```hcl
variable "name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

variable "container_name" {
  type = string
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "environment_variables" {
  type = map(string)
  default = {}
}
```

`modules/ecs/outputs.tf`
```hcl
output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}
```

`modules/rds/variables.tf`
```hcl
variable "name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "engine_version" {
  type    = string
  default = "15"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "multi_az" {
  type    = bool
  default = false
}
```

`modules/rds/outputs.tf`
```hcl
output "db_instance_endpoint" {
  value = aws_db_instance.this.address
}

output "db_instance_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}
```

環境側 `environments/dev/main.tf` の呼び出しイメージ:
```hcl
module "network" {
  source                   = "../../modules/network"
  name                     = "sample-dev"
  vpc_cidr                 = "10.0.0.0/16"
  azs                      = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]
}

module "security_group" {
  source   = "../../modules/security_group"
  name     = "sample-dev"
  vpc_id   = module.network.vpc_id
  app_port = 8080
  db_port  = 5432
}

module "iam" {
  source = "../../modules/iam"
  name   = "sample-dev"
}

module "alb" {
  source             = "../../modules/alb"
  name               = "sample-dev"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnet_ids
  security_group_ids = [module.security_group.alb_sg_id]
  target_port        = 8080
}

module "ecs" {
  source              = "../../modules/ecs"
  name                = "sample-dev"
  subnet_ids          = module.network.private_app_subnet_ids
  security_group_ids  = [module.security_group.ecs_sg_id]
  target_group_arn    = module.alb.target_group_arn
  container_name      = "app"
  container_image     = "nginx:latest"
  container_port      = 8080
  desired_count       = 2
  execution_role_arn  = module.iam.ecs_task_execution_role_arn
  task_role_arn       = module.iam.ecs_task_role_arn
  environment_variables = {
    DB_HOST = module.rds.db_instance_endpoint
    DB_PORT = tostring(module.rds.db_instance_port)
    DB_NAME = module.rds.db_name
  }
}

module "rds" {
  source                 = "../../modules/rds"
  name                   = "sample-dev"
  subnet_ids             = module.network.private_db_subnet_ids
  vpc_security_group_ids = [module.security_group.rds_sg_id]
  db_name                = "appdb"
  username               = "appuser"
  password               = var.db_password
}
```

**4. Terraformステート管理方針**

バックエンド構成:
- Terraform state は `S3` に保存する。
- 排他制御は `DynamoDB` を用いる。
- backend 用の S3 bucket と DynamoDB table は `bootstrap/backend` で先に作成する。
- S3 bucket には以下を設定する。
  - バージョニング有効化
  - SSE 有効化
  - パブリックアクセスブロック
  - 必要に応じてライフサイクル設定
- DynamoDB table は `LockID` をパーティションキーにする。

`environments/dev/backend.tf` 例:
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "3tier-webapp/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "my-terraform-locks"
    encrypt        = true
  }
}
```

環境分離戦略:
- `dev`, `stg`, `prod` ごとに `environments/` を分ける。
- 各環境は独立した `tfvars` と backend key を持つ。
- state ファイルは `key = "3tier-webapp/<env>/terraform.tfstate"` のように分離する。
- 本番と非本番で以下を変える。
  - ECS desired count
  - RDS instance class
  - RDS Multi-AZ
  - バックアップ保持日数
  - 削除保護
- さらに厳密に分離したい場合は、AWSアカウント自体を `dev/stg/prod` で分ける。

推奨運用:
- `bootstrap` とアプリ本体の state は分離する。
- `prod` には `deletion_protection = true` を有効化する。
- 機密値は `terraform.tfvars` に直書きせず、`AWS Secrets Manager` や `SSM Parameter Store` と連携する。

必要であれば次に、ここからそのまま使える `main.tf` 雛形まで具体化します。