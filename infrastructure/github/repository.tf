resource "github_repository" "managed" {
  for_each = var.protected_repositories

  name = each.value

  has_issues   = true
  has_projects = true

  allow_merge_commit = true
  allow_squash_merge = false
  allow_rebase_merge = false

  delete_branch_on_merge = true

  vulnerability_alerts = true

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }
}
