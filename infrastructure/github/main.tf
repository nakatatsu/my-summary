resource "github_repository_ruleset" "branch_protection" {
  for_each = var.protected_repositories

  name        = "branch-protection"
  repository  = each.value
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 5 # Repository admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH", "refs/heads/develop", "refs/heads/release-*", "refs/heads/hotfix-*"]
      exclude = []
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = false

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      required_check {
        context = "ci"
      }
    }
  }
}

resource "github_repository_ruleset" "code_scanning" {
  for_each = var.protected_repositories

  name        = "code-scanning"
  repository  = each.value
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 5 # Repository admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH", "refs/heads/develop", "refs/heads/release-*", "refs/heads/hotfix-*"]
      exclude = []
    }
  }

  # Provider Issue #2599 により 422 エラーが発生する可能性あり。
  # branch-protection と分離し、障害時の影響を局所化する。
  rules {
    required_code_scanning {
      required_code_scanning_tool {
        tool                      = "CodeQL"
        alerts_threshold          = "errors"
        security_alerts_threshold = "high_or_higher"
      }
    }
  }
}

resource "github_repository_ruleset" "tag_protection" {
  for_each = var.protected_repositories

  name        = "tag-protection"
  repository  = each.value
  target      = "tag"
  enforcement = "active"

  bypass_actors {
    actor_id    = 5 # Repository admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    creation = true
    update   = true
    deletion = true
  }
}
