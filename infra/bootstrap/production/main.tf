locals {
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

module "account_bootstrap" {
  source = "../../modules/account_bootstrap"

  account_id              = "991278600180"
  environment             = "production"
  github_environment      = "production"
  github_owner_id         = "6896625"
  github_repository_id    = "1333254672"
  github_repository_name  = "data-platform-aws"
  github_repository_owner = "jtrusty"
  tags                    = local.tags
}

output "terraform_deploy_role_arn" {
  description = "GitHub Actions deployment role for production."
  value       = module.account_bootstrap.deployment_role_arn
}

output "terraform_plan_role_arn" {
  description = "GitHub Actions read-only plan role for production."
  value       = module.account_bootstrap.plan_role_arn
}

output "state_bucket_name" {
  description = "Production state bucket."
  value       = module.account_bootstrap.state_bucket_name
}
