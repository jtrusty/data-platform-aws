provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.tags
  }
}

locals {
  environment      = "production"
  resource_prefix  = "data-platform-${local.environment}"
  secret_namespace = "data-platform/${local.environment}"
  vpc_cidr         = "10.60.0.0/16"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    Platform    = "data-platform"
  }
}

# Production is promoted only from a development-tested commit and uses a
# dedicated account, state, deployment role, and approval gate.
