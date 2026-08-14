variable "aws_region" {
  description = "AWS region for the development platform."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The data platform workload region is fixed to us-east-2."
  }
}

variable "aws_account_id" {
  description = "AWS account dedicated to the development environment."
  type        = string
  default     = "511492912574"

  validation {
    condition     = var.aws_account_id == "511492912574"
    error_message = "Development is fixed to AWS account 511492912574."
  }
}

variable "owner" {
  description = "Team or contact responsible for the platform."
  type        = string
  default     = "data-platform"

  validation {
    condition     = trimspace(var.owner) != ""
    error_message = "owner must not be empty."
  }
}

variable "force_destroy_buckets" {
  description = "Allow Terraform to empty platform buckets during teardown."
  type        = bool
  default     = false
}

variable "landing_expiration_days" {
  description = "Days to retain temporary landing objects."
  type        = number
  default     = 14
}

variable "athena_results_expiration_days" {
  description = "Days to retain reproducible Athena query results."
  type        = number
  default     = 14
}

variable "artifact_expiration_days" {
  description = "Days to retain current deployment artifacts."
  type        = number
}

variable "versioned_bucket_purposes" {
  description = "Bucket purposes that retain overwritten object versions."
  type        = set(string)
}

variable "queue_visibility_timeout_seconds" {
  description = "Seconds a received message remains hidden."
  type        = number
}

variable "queue_message_retention_seconds" {
  description = "Work queue message retention in seconds."
  type        = number
}

variable "dlq_message_retention_seconds" {
  description = "Dead-letter queue message retention in seconds."
  type        = number
}

variable "queue_max_receive_count" {
  description = "Receives before a message moves to its DLQ."
  type        = number
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager deletion recovery window."
  type        = number
  default     = 7
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent S3 object versions."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 7 && var.noncurrent_version_expiration_days <= 3650
    error_message = "noncurrent_version_expiration_days must be between 7 and 3650."
  }
}

variable "metadata_read_capacity" {
  description = "Provisioned DynamoDB metadata read capacity units."
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_read_capacity >= 1 && floor(var.metadata_read_capacity) == var.metadata_read_capacity
    error_message = "metadata_read_capacity must be a positive whole number."
  }
}

variable "metadata_write_capacity" {
  description = "Provisioned DynamoDB metadata write capacity units."
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_write_capacity >= 1 && floor(var.metadata_write_capacity) == var.metadata_write_capacity
    error_message = "metadata_write_capacity must be a positive whole number."
  }
}

variable "metadata_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery."
  type        = bool
  default     = false
}

variable "metadata_deletion_protection" {
  description = "Enable DynamoDB deletion protection."
  type        = bool
  default     = false
}

variable "secret_names" {
  description = "Relative data-platform secret container paths; values are populated outside Terraform."
  type        = set(string)
  default     = []
}

variable "analytics_availability_zones" {
  description = "Three distinct Ohio availability zones for private Redshift Serverless."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "athena_bytes_scanned_cutoff_per_query" {
  description = "Hard bytes-scanned limit for one Athena query."
  type        = number
  default     = 10737418240
}

variable "redshift_base_capacity" {
  description = "Redshift Serverless base capacity in RPUs."
  type        = number
  default     = 4
}

variable "redshift_max_capacity" {
  description = "Redshift Serverless maximum capacity in RPUs."
  type        = number
  default     = 4
}

variable "redshift_monthly_rpu_hours" {
  description = "Monthly Redshift compute hard limit in RPU-hours."
  type        = number
  default     = 16
}

variable "redshift_max_query_execution_seconds" {
  description = "Maximum execution time for an individual Redshift query."
  type        = number
  default     = 900
}

variable "redshift_log_retention_days" {
  description = "CloudWatch retention for Redshift audit logs."
  type        = number
  default     = 14
}

variable "alert_email" {
  description = "Address subscribed to budget and platform alarms. Supplied through a gitignored tfvars file locally and a GitHub Environment secret in CI; never committed."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for this account."
  type        = number
  default     = 25
}

variable "athena_monthly_bytes_limit" {
  description = "Month-to-date Athena scanned bytes after which the workgroup is disabled."
  type        = number
  default     = 214748364800
}

variable "enable_security_hub" {
  description = "Enable Security Hub and the foundational standard. This is the most expensive detective control, billed per check."
  type        = bool
  default     = true
}

variable "audit_log_expiration_days" {
  description = "Days to retain AWS Config snapshots and VPC flow log records."
  type        = number
  default     = 90
}

variable "guard_log_retention_days" {
  description = "CloudWatch retention for the Athena spend guard's own logs."
  type        = number
  default     = 14
}
