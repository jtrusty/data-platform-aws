variable "aws_account_id" {
  description = "AWS account that owns the environment foundation."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region containing the environment foundation."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The data platform workload region is fixed to us-east-2."
  }
}

variable "environment" {
  description = "Environment identity used in every platform resource name."
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

variable "secret_namespace" {
  description = "Optional environment-qualified Secrets Manager namespace."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.secret_namespace == null ? true : var.secret_namespace == "data-platform/${var.environment}"
    error_message = "secret_namespace must equal data-platform/{environment}."
  }
}

variable "permissions_boundary_arn" {
  description = "Terraform-owned maximum-permissions policy applied to every runtime role."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:iam::${var.aws_account_id}:policy/.+$", var.permissions_boundary_arn))
    error_message = "permissions_boundary_arn must be an IAM policy ARN in the environment account."
  }
}

variable "force_destroy_buckets" {
  description = "Allow deletion of non-empty buckets in the disposable sandbox only."
  type        = bool
  default     = false

  validation {
    condition     = !var.force_destroy_buckets || var.environment == "sandbox"
    error_message = "force_destroy_buckets may be true only in sandbox."
  }
}

variable "versioned_bucket_purposes" {
  description = "Bucket purposes that retain overwritten and deleted object versions."
  type        = set(string)
  default     = ["bronze", "artifacts"]

  validation {
    condition = alltrue([
      for purpose in var.versioned_bucket_purposes :
      contains(["landing", "bronze", "silver", "artifacts", "athena-results"], purpose)
    ])
    error_message = "versioned_bucket_purposes contains an unknown platform bucket purpose."
  }
}

variable "landing_expiration_days" {
  description = "Days to retain temporary landing objects."
  type        = number
  default     = 7

  validation {
    condition     = var.landing_expiration_days >= 1 && var.landing_expiration_days <= 3650
    error_message = "landing_expiration_days must be between 1 day and 10 years."
  }
}

variable "athena_results_expiration_days" {
  description = "Days to retain reproducible Athena query results."
  type        = number
  default     = 7

  validation {
    condition     = var.athena_results_expiration_days >= 1 && var.athena_results_expiration_days <= 3650
    error_message = "athena_results_expiration_days must be between 1 day and 10 years."
  }
}

variable "artifact_expiration_days" {
  description = "Days to retain current deployment artifacts."
  type        = number
  default     = 30

  validation {
    condition     = var.artifact_expiration_days >= 7 && var.artifact_expiration_days <= 3650
    error_message = "artifact_expiration_days must be between 7 days and 10 years."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent object versions in versioned buckets."
  type        = number
  default     = 7

  validation {
    condition     = var.noncurrent_version_expiration_days >= 7 && var.noncurrent_version_expiration_days <= 3650
    error_message = "noncurrent_version_expiration_days must be between 7 days and 10 years."
  }
}

variable "queue_visibility_timeout_seconds" {
  description = "Time a received work message remains hidden from other consumers."
  type        = number
  default     = 300

  validation {
    condition     = var.queue_visibility_timeout_seconds >= 0 && var.queue_visibility_timeout_seconds <= 43200
    error_message = "queue_visibility_timeout_seconds must be between 0 and 43200."
  }
}

variable "queue_message_retention_seconds" {
  description = "Retention period for work queue messages."
  type        = number
  default     = 345600

  validation {
    condition     = var.queue_message_retention_seconds >= 60 && var.queue_message_retention_seconds <= 1209600
    error_message = "queue_message_retention_seconds must be between 60 and 1209600."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Retention period for failed messages in dead-letter queues."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds >= var.queue_message_retention_seconds && var.dlq_message_retention_seconds <= 1209600
    error_message = "dlq_message_retention_seconds must be at least the work queue retention and no more than 1209600."
  }
}

variable "queue_max_receive_count" {
  description = "Failed receives allowed before a message is sent to its DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.queue_max_receive_count >= 1 && var.queue_max_receive_count <= 1000
    error_message = "queue_max_receive_count must be between 1 and 1000."
  }
}

variable "metadata_read_capacity" {
  description = "Provisioned metadata table read capacity units."
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_read_capacity >= 1 && var.metadata_read_capacity <= 40000 && floor(var.metadata_read_capacity) == var.metadata_read_capacity
    error_message = "metadata_read_capacity must be a whole number between 1 and 40000."
  }
}

variable "metadata_write_capacity" {
  description = "Provisioned metadata table write capacity units."
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_write_capacity >= 1 && var.metadata_write_capacity <= 40000 && floor(var.metadata_write_capacity) == var.metadata_write_capacity
    error_message = "metadata_write_capacity must be a whole number between 1 and 40000."
  }
}

variable "metadata_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery; required in production."
  type        = bool
  default     = false

  validation {
    condition     = var.environment != "production" || var.metadata_point_in_time_recovery
    error_message = "metadata_point_in_time_recovery must be true in production."
  }
}

variable "metadata_deletion_protection" {
  description = "Enable DynamoDB deletion protection; required in production."
  type        = bool
  default     = false

  validation {
    condition     = var.environment != "production" || var.metadata_deletion_protection
    error_message = "metadata_deletion_protection must be true in production."
  }
}

variable "secret_names" {
  description = "Opt-in secret container suffixes; Terraform never accepts or writes secret values."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for name in var.secret_names :
      can(regex("^[A-Za-z0-9_+=.@/-]+$", name)) &&
      !startswith(name, "/") &&
      !endswith(name, "/") &&
      !strcontains(name, "..") &&
      !strcontains(name, "//")
    ])
    error_message = "secret_names must be safe relative paths without leading/trailing slashes, empty segments, or parent traversal."
  }
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager deletion recovery window; use zero only for disposable environments."
  type        = number
  default     = 0

  validation {
    condition     = var.secret_recovery_window_days == 0 || (var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30)
    error_message = "secret_recovery_window_days must be 0 or between 7 and 30."
  }

  validation {
    condition = (
      length(var.secret_names) == 0 ||
      var.environment == "sandbox" ||
      var.secret_recovery_window_days >= 7
    )
    error_message = "Development and production secret containers must have a recovery window of at least 7 days."
  }

  validation {
    condition     = length(var.secret_names) == 0 || var.environment != "production" || var.secret_recovery_window_days == 30
    error_message = "Production secret containers must have a 30-day recovery window."
  }
}

variable "tags" {
  description = "Mandatory data-platform boundary tags."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Environment", "ManagedBy", "Owner", "Platform"] :
      contains(keys(var.tags), key) && trimspace(lookup(var.tags, key, "")) != ""
    ])
    error_message = "tags must contain non-empty Environment, ManagedBy, Owner, and Platform values."
  }

  validation {
    condition = (
      lookup(var.tags, "Environment", "") == var.environment &&
      lookup(var.tags, "ManagedBy", "") == "terraform" &&
      lookup(var.tags, "Platform", "") == "data-platform"
    )
    error_message = "Environment must match environment, ManagedBy must be terraform, and Platform must be data-platform."
  }
}
