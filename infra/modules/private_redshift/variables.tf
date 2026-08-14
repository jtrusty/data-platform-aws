variable "aws_account_id" {
  description = "AWS account that owns the private warehouse."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region containing the private warehouse."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The data platform workload region is fixed to us-east-2."
  }
}

variable "availability_zones" {
  description = "Exactly three distinct Ohio availability zones for Redshift Serverless."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]

  validation {
    condition = (
      length(var.availability_zones) == 3 &&
      length(toset(var.availability_zones)) == 3 &&
      alltrue([for zone in var.availability_zones : can(regex("^us-east-2[a-z]$", zone))])
    )
    error_message = "availability_zones must contain three distinct us-east-2 availability zones."
  }
}

variable "environment" {
  description = "Environment identity used in every warehouse resource name."
  type        = string

  validation {
    condition     = contains(["sandbox", "development", "production"], var.environment)
    error_message = "environment must be sandbox, development, or production."
  }
}

variable "resource_prefix" {
  description = "Environment-qualified data platform resource prefix."
  type        = string

  validation {
    condition     = var.resource_prefix == "data-platform-${var.environment}"
    error_message = "resource_prefix must equal data-platform-{environment}."
  }
}

variable "vpc_cidr" {
  description = "Dedicated environment VPC CIDR."
  type        = string

  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 2)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid IPv4 /16 with room for three private /24 subnets."
  }
}

variable "redshift_role_arn" {
  description = "Exact Terraform-owned Redshift runtime role associated with the namespace."
  type        = string

  validation {
    condition     = var.redshift_role_arn == "arn:aws:iam::${var.aws_account_id}:role/data-platform/runtime/${var.resource_prefix}-redshift"
    error_message = "redshift_role_arn must be the exact environment Redshift runtime role."
  }
}

variable "silver_bucket_arn" {
  description = "Exact Silver bucket reachable through the private S3 endpoint."
  type        = string

  validation {
    condition     = var.silver_bucket_arn == "arn:aws:s3:::${var.resource_prefix}-silver-${var.aws_account_id}"
    error_message = "silver_bucket_arn must be the exact environment and account Silver bucket."
  }
}

variable "base_capacity" {
  description = "Base Redshift Serverless capacity in RPUs."
  type        = number
  default     = 4

  validation {
    condition     = var.base_capacity >= 4 && var.base_capacity <= 1024 && floor(var.base_capacity) == var.base_capacity && var.base_capacity % 4 == 0
    error_message = "base_capacity must be a whole multiple of 4 from 4 through 1024 RPUs."
  }
}

variable "max_capacity" {
  description = "Maximum Redshift Serverless capacity in RPUs."
  type        = number
  default     = 4

  validation {
    condition     = var.max_capacity >= var.base_capacity && var.max_capacity <= 1024 && floor(var.max_capacity) == var.max_capacity && var.max_capacity % 4 == 0
    error_message = "max_capacity must be a whole multiple of 4 between base_capacity and 1024 RPUs."
  }
}

variable "monthly_rpu_hours" {
  description = "Monthly compute usage limit in aggregate RPU-hours; deactivation occurs when reached."
  type        = number
  default     = 16

  validation {
    condition     = var.monthly_rpu_hours >= 1 && var.monthly_rpu_hours <= 10000 && floor(var.monthly_rpu_hours) == var.monthly_rpu_hours
    error_message = "monthly_rpu_hours must be a positive whole number no greater than 10000."
  }
}

variable "max_query_execution_seconds" {
  description = "Maximum execution time for an individual Redshift query."
  type        = number
  default     = 900

  validation {
    condition     = var.max_query_execution_seconds >= 60 && var.max_query_execution_seconds <= 86400 && floor(var.max_query_execution_seconds) == var.max_query_execution_seconds
    error_message = "max_query_execution_seconds must be a whole number from 60 through 86400."
  }
}

variable "log_retention_days" {
  description = "Finite CloudWatch retention for all Redshift audit logs."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs-supported retention value."
  }
}

variable "tags" {
  description = "Mandatory data-platform boundary tags."
  type        = map(string)

  validation {
    condition = (
      lookup(var.tags, "Environment", "") == var.environment &&
      lookup(var.tags, "ManagedBy", "") == "terraform" &&
      lookup(var.tags, "Platform", "") == "data-platform" &&
      trimspace(lookup(var.tags, "Owner", "")) != ""
    )
    error_message = "tags must identify the matching environment, Terraform, data platform, and a non-empty owner."
  }
}
