output "audit_bucket_name" {
  description = "Organization audit log bucket name."
  value       = aws_s3_bucket.audit.id
}

output "trail_arn" {
  description = "Organization CloudTrail ARN."
  value       = aws_cloudtrail.organization.arn
}

output "trail_name" {
  description = "Organization CloudTrail name."
  value       = aws_cloudtrail.organization.name
}

output "log_retention_days" {
  description = "Days audit objects are retained before expiration."
  value       = var.log_retention_days
}

output "alert_topic_arn" {
  description = "SNS topic receiving management-account budget alerts."
  value       = aws_sns_topic.alerts.arn
}

output "monthly_budget_usd" {
  description = "Management-account monthly cost budget in USD."
  value       = var.monthly_budget_usd
}

output "guardduty_detector_id" {
  description = "GuardDuty detector protecting the management account."
  value       = aws_guardduty_detector.management.id
}

output "security_hub_enabled" {
  description = "Whether Security Hub is enabled in the management account."
  value       = var.enable_security_hub
}
