locals {
  tags = {
    Environment = "development"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

module "account_bootstrap" {
  source = "../../modules/account_bootstrap"

  account_id              = var.account_id
  environment             = "development"
  github_environment      = "development"
  github_owner_id         = var.github_owner_id
  github_repository_id    = var.github_repository_id
  github_repository_name  = var.github_repository_name
  github_repository_owner = var.github_repository_owner
  tags                    = local.tags
}

output "terraform_deploy_role_arn" {
  description = "GitHub Actions deployment role for development."
  value       = module.account_bootstrap.deployment_role_arn
}

output "state_bucket_name" {
  description = "Development state bucket."
  value       = module.account_bootstrap.state_bucket_name
}

output "terraform_plan_role_arn" {
  description = "GitHub Actions read-only plan role for development."
  value       = module.account_bootstrap.plan_role_arn
}
