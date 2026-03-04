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