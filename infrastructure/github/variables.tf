variable "protected_repositories" {
  description = "main-branch-protection ルールを適用するリポジトリ一覧"
  type        = set(string)
}
