variable "name" {
  description = "リポジトリ名"
  type        = string
}

variable "allow_merge_commit" {
  description = "マージコミットを許可するか"
  type        = bool
  default     = true
}

variable "allow_squash_merge" {
  description = "スカッシュマージを許可するか"
  type        = bool
  default     = false
}

variable "allow_rebase_merge" {
  description = "リベースマージを許可するか"
  type        = bool
  default     = false
}

variable "delete_branch_on_merge" {
  description = "マージ後にブランチを自動削除するか"
  type        = bool
  default     = true
}
