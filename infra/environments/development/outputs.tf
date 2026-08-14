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
  description = "Identifiers for the development data foundation."
  value = {
    bucket_names           = module.data_foundation.bucket_names
    dead_letter_queue_arns = module.data_foundation.dead_letter_queue_arns
    metadata_table_name    = module.data_foundation.metadata_table_name
    runtime_role_arns      = module.data_foundation.runtime_role_arns
    secret_arns            = module.data_foundation.secret_arns
    work_queue_arns        = module.data_foundation.queue_arns
  }
}

output "analytics" {
  description = "Cost-controlled Athena and private Redshift configuration."
  value = {
    athena_catalog_databases   = module.athena_analytics.catalog_database_names
    athena_query_cutoff_bytes  = module.athena_analytics.bytes_scanned_cutoff_per_query
    athena_workgroup_name      = module.athena_analytics.workgroup_name
    redshift_base_capacity     = module.private_redshift.base_capacity
    redshift_max_capacity      = module.private_redshift.max_capacity
    redshift_monthly_rpu_hours = module.private_redshift.monthly_rpu_hours
    redshift_namespace_name    = module.private_redshift.namespace_name
    redshift_private           = !module.private_redshift.publicly_accessible
    redshift_workgroup_name    = module.private_redshift.workgroup_name
    vpc_id                     = module.private_redshift.vpc_id
  }
}
