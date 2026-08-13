locals {
  tags = {
    Environment = "organization"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

module "state_backend" {
  source = "../../modules/state_backend"

  account_id  = "699599381258"
  environment = "organization"
  tags        = local.tags
}

output "state_bucket_name" {
  description = "Management-account state bucket for organization configuration."
  value       = module.state_backend.bucket_name
}

output "state_kms_key_arn" {
  description = "Management-account state encryption key."
  value       = module.state_backend.kms_key_arn
}
