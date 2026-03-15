output "ruleset_id" {
  description = "The ID of the main branch protection ruleset"
  value       = github_repository_ruleset.main_branch_protection.ruleset_id
}
