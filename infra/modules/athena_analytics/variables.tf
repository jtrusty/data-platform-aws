variable "aws_account_id" {
  description = "AWS account that owns the Athena workgroup and result bucket."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "environment" {
  description = "Environment identity used in every analytics resource name."
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

variable "athena_results_bucket_id" {
  description = "Exact platform bucket used for Athena query results."
  type        = string

  validation {
    condition     = var.athena_results_bucket_id == "${var.resource_prefix}-athena-results-${var.aws_account_id}"
    error_message = "athena_results_bucket_id must be the exact environment and account results bucket."
  }
}

variable "bronze_bucket_id" {
  description = "Exact platform Bronze bucket represented by the baseline catalog database."
  type        = string

  validation {
    condition     = var.bronze_bucket_id == "${var.resource_prefix}-bronze-${var.aws_account_id}"
    error_message = "bronze_bucket_id must be the exact environment and account Bronze bucket."
  }
}

variable "silver_bucket_id" {
  description = "Exact platform Silver bucket represented by the baseline catalog database."
  type        = string

  validation {
    condition     = var.silver_bucket_id == "${var.resource_prefix}-silver-${var.aws_account_id}"
    error_message = "silver_bucket_id must be the exact environment and account Silver bucket."
  }
}

variable "bytes_scanned_cutoff_per_query" {
  description = "Hard maximum bytes scanned by one Athena query; 10 GiB costs about five cents at the current standard rate."
  type        = number
  default     = 10737418240

  validation {
    condition = (
      var.bytes_scanned_cutoff_per_query >= 10485760 &&
      var.bytes_scanned_cutoff_per_query <= 1099511627776 &&
      floor(var.bytes_scanned_cutoff_per_query) == var.bytes_scanned_cutoff_per_query
    )
    error_message = "bytes_scanned_cutoff_per_query must be a whole number from 10 MiB through 1 TiB."
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
