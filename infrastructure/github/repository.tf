resource "github_repository" "managed" {
  for_each = var.protected_repositories

  name = each.value

  allow_merge_commit = true
  allow_squash_merge = false
  allow_rebase_merge = false

  delete_branch_on_merge = true

  vulnerability_alerts = true

  security_and_analysis {
    advanced_security {
      status = "enabled"
    }
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }
}
