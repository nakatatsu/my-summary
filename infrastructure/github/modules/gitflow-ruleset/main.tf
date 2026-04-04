locals {
  protected_refs = ["~DEFAULT_BRANCH", "refs/heads/develop", "refs/heads/release-*", "refs/heads/hotfix-*"]
}

resource "github_repository_ruleset" "branch_protection" {
  name        = "gitflow-branch-protection"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 5 # Repository admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = local.protected_refs
      exclude = []
    }
  }

  rules {
    # develop を含む全保護ブランチに対して削除禁止が適用される
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
  name        = "code-scanning"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  bypass_actors {
    actor_id    = 5 # Repository admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  conditions {
    ref_name {
      include = local.protected_refs
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

# バイパスなしのブランチ削除禁止。
# delete_branch_on_merge による自動削除も含め、誰も対象ブランチを削除できない。
resource "github_repository_ruleset" "branch_deletion_protection" {
  name        = "branch-deletion-protection"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  # bypass_actors を意図的に設定しない

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH", "refs/heads/develop", "refs/heads/release-*"]
      exclude = []
    }
  }

  rules {
    deletion = true
  }
}

resource "github_repository_ruleset" "tag_protection" {
  name        = "tag-protection"
  repository  = var.repository
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
