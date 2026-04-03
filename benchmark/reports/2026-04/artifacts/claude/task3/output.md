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
