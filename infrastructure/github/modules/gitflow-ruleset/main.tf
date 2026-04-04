locals {
  protected_refs = ["~DEFAULT_BRANCH", "refs/heads/develop", "refs/heads/release-*", "refs/heads/hotfix-*"]
}

# バイパスなし。緊急時はブレイクグラスで一時的にバイパス許可する運用。
resource "github_repository_ruleset" "gitflow_branch_protection" {
  name        = "gitflow-branch-protection"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = local.protected_refs
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

    required_code_scanning {
      required_code_scanning_tool {
        tool                      = "CodeQL"
        alerts_threshold          = "errors"
        security_alerts_threshold = "high_or_higher"
      }
    }
  }
}
