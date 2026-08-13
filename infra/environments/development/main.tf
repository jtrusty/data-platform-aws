provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.tags
  }
}

locals {
  environment          = "development"
  resource_prefix      = "data-platform-${local.environment}"
  secret_namespace     = "data-platform/${local.environment}"
  vpc_cidr             = "10.50.0.0/16"
  runtime_boundary_arn = "arn:aws:iam::${var.aws_account_id}:policy/bootstrap/jtrusty-data-platform-runtime-boundary-${local.environment}"

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
