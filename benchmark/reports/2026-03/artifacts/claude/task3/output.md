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
