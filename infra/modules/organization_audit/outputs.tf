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
