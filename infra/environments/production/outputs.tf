output "aws_account_id" {
  description = "Approved AWS account for this environment."
  value       = var.aws_account_id
}

output "environment" {
  description = "Fixed environment identity."
  value       = local.environment
}

output "resource_prefix" {
  description = "Required prefix for environment resources."
  value       = local.resource_prefix
}

output "secret_namespace" {
  description = "Required Secrets Manager namespace."
  value       = local.secret_namespace
}

output "vpc_cidr" {
  description = "Dedicated environment VPC CIDR."
  value       = local.vpc_cidr
}
