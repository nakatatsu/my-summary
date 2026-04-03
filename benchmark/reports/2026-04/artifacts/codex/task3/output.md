- [CRITICAL] `aws_db_instance.main` : `password = "password123"` のようにDBパスワードをTerraformコードへ平文で埋め込んでいる -> `variable` + `sensitive = true` を使い、実値は `tfvars` や Secrets Manager/SSM Parameter Store から参照する
- [CRITICAL] `aws_db_instance.main` : `publicly_accessible = true` によりRDSがインターネット到達可能になり、侵害リスクが高い -> `publicly_accessible = false` とし、Private Subnet内へ配置してSecurity Groupで接続元を限定する
- [CRITICAL] `aws_security_group.web` : `0.0.0.0/0` に対して TCP 全ポート (`0-65535`) を許可しており、全面的に外部公開されている -> 必要なポートだけを許可し、送信元CIDRまたはALB/踏み台/別SGに限定する
- [HIGH] `aws_db_instance.main` : `storage_encrypted = false` でDBストレージ暗号化が無効 -> `storage_encrypted = true` を設定し、必要に応じてKMSキーを明示する
- [HIGH] `aws_db_instance.main` : `skip_final_snapshot = true` により削除時に最終バックアップが残らず、障害や誤削除時の復旧性が低い -> `skip_final_snapshot = false` とし、`final_snapshot_identifier` を設定する
- [HIGH] `aws_db_instance.main` : DB Subnet Group や Security Group の関連付けがなく、VPC内の適切な閉域配置が担保されていない -> `db_subnet_group_name` と `vpc_security_group_ids` を設定し、private subnet用の構成を追加する
- [HIGH] `aws_s3_bucket.data` : バケットに暗号化設定がなく、保存データ保護が不十分 -> `server_side_encryption_configuration` を設定して SSE-S3 または SSE-KMS を有効化する
- [HIGH] `aws_s3_bucket.data` : パブリックアクセスブロック設定がなく、将来的な公開事故を防げない -> `aws_s3_bucket_public_access_block` を追加して4項目すべて有効化する
- [MEDIUM] `aws_s3_bucket.data` : バケット名 `my-app-data-bucket` はグローバル一意制約により衝突しやすく、環境差分にも弱い -> 環境名やアカウントIDを含めた一意な命名規則に変更する
- [MEDIUM] `aws_security_group.web` : egress が全宛先・全プロトコル許可になっており、侵害時の外部通信を無制限にしてしまう -> 必要な宛先とポートのみに送信制御を絞る
- [MEDIUM] `provider "aws"` : 認証情報や共通タグ、Terraform/AWS Provider のバージョン制約がなく、再現性と運用統制が弱い -> `required_version` と `required_providers` を定義し、`default_tags` 等も検討する
- [MEDIUM] `aws_db_instance.main` : `backup_retention_period` が未設定で、自動バックアップ運用が不明確 -> 保持日数を明示し、必要なら `deletion_protection = true` も有効化する
- [LOW] `aws_vpc.main` : DNSホスト名やDNSサポート設定がなく、後続のRDS/EC2運用で名前解決要件を満たせない可能性がある -> `enable_dns_support = true` と `enable_dns_hostnames = true` を明示する
- [LOW] 全体 : 監査用のタグ付けがなく、コスト管理・所有者管理・運用追跡がしづらい -> 各リソースまたはProviderの `default_tags` で `Environment` `Owner` `Service` などを付与する

最優先で直すべきTOP3
1. `aws_db_instance.main` の平文パスワード管理をやめ、Secrets Manager/SSM + `sensitive` 変数へ移行する
2. `aws_db_instance.main` の `publicly_accessible = true` を廃止し、Private Subnet + 制限されたSecurity Groupへ移す
3. `aws_security_group.web` の `0.0.0.0/0` 向け全TCPポート開放を必要最小限のポート・送信元に絞る