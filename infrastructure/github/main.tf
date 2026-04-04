# =============================================================================
# Repository
# =============================================================================

module "repository" {
  source   = "./modules/repository"
  for_each = toset(["mynote", "psm"])
  name     = each.value
}

# =============================================================================
# Ruleset — main ブランチ運用
# =============================================================================

module "mainbase_ruleset" {
  source     = "./modules/mainbase-ruleset"
  for_each   = toset(["mynote"])
  repository = each.value
}

# =============================================================================
# Ruleset — GitFlow (main + develop + release + hotfix)
# =============================================================================

module "gitflow_ruleset" {
  source     = "./modules/gitflow-ruleset"
  for_each   = toset(["psm"])
  repository = each.value
}
