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
    required_linear_history = true

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
