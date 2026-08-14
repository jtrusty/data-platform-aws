locals {
  alert_email = var.alert_email == null ? null : (trimspace(var.alert_email) == "" ? null : var.alert_email)

  tags = {
    Environment = "organization"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

module "identity_center_access" {
  source = "../modules/identity_center_access"

  management_account_id       = var.management_account_id
  workload_accounts           = var.workload_accounts
  organization_admin_user_ids = var.organization_admin_user_ids
  instance_arn                = var.identity_center_instance_arn
  identity_store_id           = var.identity_store_id
  platform_admins_group_id    = var.platform_admins_group_id
  data_engineers_group_id     = var.data_engineers_group_id
}

# Organization-wide management-event audit. Management events are free for the
# first copy per account; only the capped S3 storage below is billed.
module "organization_audit" {
  source = "../modules/organization_audit"

  management_account_id = var.management_account_id
  alert_email           = local.alert_email
  enable_security_hub   = var.enable_security_hub
  monthly_budget_usd    = var.monthly_budget_usd
  organization_trail    = var.organization_trail
  member_account_ids    = values(var.workload_accounts)
  tags                  = local.tags
}

output "permission_set_arns" {
  description = "Identity Center permission sets managed by this root."
  value       = module.identity_center_access.permission_set_arns
}

output "audit_bucket_name" {
  description = "Organization CloudTrail audit log bucket."
  value       = module.organization_audit.audit_bucket_name
}

output "organization_trail_arn" {
  description = "Organization CloudTrail ARN covering every member account."
  value       = module.organization_audit.trail_arn
}

output "organization_alert_topic_arn" {
  description = "SNS topic receiving management-account budget alerts."
  value       = module.organization_audit.alert_topic_arn
}
