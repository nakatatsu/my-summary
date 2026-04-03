resource "github_repository_ruleset" "main_branch_protection" {
  for_each = var.protected_repositories

  name        = "main-branch-protection"
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
      include = ["~DEFAULT_BRANCH"]
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

    # TODO: required_code_scanning ブロックの利用を検討（Provider バグ修正待ち）
    # Provider Issue #2599 により 422 エラーが発生する可能性あり。
    # 失敗した場合は required_status_checks に CodeQL チェックを追加してフォールバックする。
    required_code_scanning {
      required_code_scanning_tool {
        tool                         = "CodeQL"
        alerts_threshold             = "errors"
        security_alerts_threshold    = "high_or_higher"
      }
    }
  }
}

resource "github_repository_ruleset" "develop_branch_protection" {
  for_each = var.protected_repositories

  name        = "develop-branch-protection"
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
      include = ["refs/heads/develop"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = false
      require_last_push_approval        = false
      required_review_thread_resolution = false
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      required_check {
        context = "ci"
      }
    }
  }
}

resource "github_repository_ruleset" "release_branch_protection" {
  for_each = var.protected_repositories

  name        = "release-branch-protection"
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
      include = ["refs/heads/release-*"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

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

resource "github_repository_ruleset" "hotfix_branch_protection" {
  for_each = var.protected_repositories

  name        = "hotfix-branch-protection"
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
      include = ["refs/heads/hotfix-*"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

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
