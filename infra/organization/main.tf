locals {
  tags = {
    Environment = "organization"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

module "identity_center_access" {
  source = "../modules/identity_center_access"

  organization_admin_user_ids = [
    "c1bba500-a0e1-70e7-52c2-5101377f116d",
  ]
}

# Organization-wide management-event audit. Management events are free for the
# first copy per account; only the capped S3 storage below is billed.
module "organization_audit" {
  source = "../modules/organization_audit"

  alert_email        = var.alert_email
  monthly_budget_usd = var.monthly_budget_usd
  tags               = local.tags
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
