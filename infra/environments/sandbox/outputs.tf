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

output "foundation" {
  description = "Identifiers for the sandbox data foundation."
  value = {
    bucket_names           = module.data_foundation.bucket_names
    dead_letter_queue_arns = module.data_foundation.dead_letter_queue_arns
    metadata_table_name    = module.data_foundation.metadata_table_name
    runtime_role_arns      = module.data_foundation.runtime_role_arns
    secret_arns            = module.data_foundation.secret_arns
    work_queue_arns        = module.data_foundation.queue_arns
  }
}
