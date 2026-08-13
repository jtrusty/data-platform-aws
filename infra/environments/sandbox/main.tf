provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.tags
  }
}

locals {
  environment      = "sandbox"
  resource_prefix  = "data-platform-${local.environment}"
  secret_namespace = "data-platform/${local.environment}"
  vpc_cidr         = "10.40.0.0/16"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    Platform    = "data-platform"
  }
}

# Sandbox is intentionally disposable. Platform modules composed here must use
# local.resource_prefix, local.secret_namespace, and local.tags.
