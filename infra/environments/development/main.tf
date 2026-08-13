provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.tags
  }
}

locals {
  environment      = "development"
  resource_prefix  = "data-platform-${local.environment}"
  secret_namespace = "data-platform/${local.environment}"
  vpc_cidr         = "10.50.0.0/16"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    Platform    = "data-platform"
  }
}

# Development is the first persistent CI deployment. Successful development
# verification gates promotion of the same commit and artifacts to production.
