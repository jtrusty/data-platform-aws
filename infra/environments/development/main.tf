provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.tags
  }
}

locals {
  environment              = "development"
  resource_prefix          = "data-platform-${local.environment}"
  secret_namespace         = "data-platform/${local.environment}"
  vpc_cidr                 = "10.50.0.0/16"
  runtime_boundary_arn     = "arn:aws:iam::${var.aws_account_id}:policy/bootstrap/jtrusty-data-platform-runtime-boundary-${local.environment}"
  config_recorder_role_arn = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    Platform    = "data-platform"
  }
}

# Development is the first persistent CI deployment. Successful development
# verification gates promotion of the same commit and artifacts to production.
module "data_foundation" {
  source = "../../modules/data_foundation"

  aws_account_id                     = var.aws_account_id
  environment                        = local.environment
  resource_prefix                    = local.resource_prefix
  secret_namespace                   = local.secret_namespace
  permissions_boundary_arn           = local.runtime_boundary_arn
  force_destroy_buckets              = var.force_destroy_buckets
  audit_log_expiration_days          = var.audit_log_expiration_days
  landing_expiration_days            = var.landing_expiration_days
  athena_results_expiration_days     = var.athena_results_expiration_days
  artifact_expiration_days           = var.artifact_expiration_days
  versioned_bucket_purposes          = var.versioned_bucket_purposes
  queue_visibility_timeout_seconds   = var.queue_visibility_timeout_seconds
  queue_message_retention_seconds    = var.queue_message_retention_seconds
  dlq_message_retention_seconds      = var.dlq_message_retention_seconds
  queue_max_receive_count            = var.queue_max_receive_count
  metadata_deletion_protection       = var.metadata_deletion_protection
  metadata_point_in_time_recovery    = var.metadata_point_in_time_recovery
  metadata_read_capacity             = var.metadata_read_capacity
  metadata_write_capacity            = var.metadata_write_capacity
  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
  secret_recovery_window_days        = var.secret_recovery_window_days
  secret_names                       = var.secret_names
  tags                               = local.tags
}

module "athena_analytics" {
  source = "../../modules/athena_analytics"

  aws_account_id                 = var.aws_account_id
  environment                    = local.environment
  resource_prefix                = local.resource_prefix
  athena_results_bucket_id       = module.data_foundation.bucket_names["athena-results"]
  bronze_bucket_id               = module.data_foundation.bucket_names.bronze
  silver_bucket_id               = module.data_foundation.bucket_names.silver
  bytes_scanned_cutoff_per_query = var.athena_bytes_scanned_cutoff_per_query
  tags                           = local.tags
}

module "private_redshift" {
  source = "../../modules/private_redshift"

  aws_account_id              = var.aws_account_id
  availability_zones          = var.analytics_availability_zones
  environment                 = local.environment
  resource_prefix             = local.resource_prefix
  vpc_cidr                    = local.vpc_cidr
  redshift_role_arn           = module.data_foundation.runtime_role_arns.redshift
  silver_bucket_arn           = module.data_foundation.bucket_arns.silver
  base_capacity               = var.redshift_base_capacity
  max_capacity                = var.redshift_max_capacity
  monthly_rpu_hours           = var.redshift_monthly_rpu_hours
  max_query_execution_seconds = var.redshift_max_query_execution_seconds
  log_retention_days          = var.redshift_log_retention_days
  tags                        = local.tags
}

# Budget notifications and the Athena spend guard. AWS Budgets only notifies, so
# the guard function is what actually stops the platform's most open-ended cost.
module "platform_observability" {
  source = "../../modules/platform_observability"

  aws_account_id             = var.aws_account_id
  environment                = local.environment
  resource_prefix            = local.resource_prefix
  alert_email                = var.alert_email
  monthly_budget_usd         = var.monthly_budget_usd
  athena_workgroup_name      = module.athena_analytics.workgroup_name
  athena_monthly_bytes_limit = var.athena_monthly_bytes_limit
  dead_letter_queue_names    = toset(values(module.data_foundation.dead_letter_queue_names))
  guard_role_arn             = module.data_foundation.athena_guard_role_arn
  log_retention_days         = var.guard_log_retention_days
  tags                       = local.tags
}

module "platform_detection" {
  source = "../../modules/platform_detection"

  aws_account_id           = var.aws_account_id
  environment              = local.environment
  resource_prefix          = local.resource_prefix
  config_bucket_id         = module.data_foundation.bucket_names["config"]
  flow_log_bucket_arn      = module.data_foundation.bucket_arns["flow-logs"]
  vpc_id                   = module.private_redshift.vpc_id
  config_recorder_role_arn = local.config_recorder_role_arn
  enable_security_hub      = var.enable_security_hub
  tags                     = local.tags
}
