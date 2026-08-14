variable "aws_account_id" {
  description = "AWS account that owns the alerting and spend controls."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region containing the alarms and alert topic."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The data platform workload region is fixed to us-east-2."
  }
}

variable "environment" {
  description = "Environment identity used in every alerting resource name."
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

variable "alert_email" {
  description = "Address subscribed to platform alerts. Never committed; supplied through a gitignored tfvars file locally and a GitHub Environment secret in CI."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = var.alert_email == null ? true : can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "alert_email must be null or a single valid email address."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for this account. Notification only; AWS Budgets does not stop spend."
  type        = number
  default     = 25

  validation {
    condition     = var.monthly_budget_usd >= 1 && var.monthly_budget_usd <= 1000
    error_message = "monthly_budget_usd must be between 1 and 1000."
  }
}

variable "athena_workgroup_name" {
  description = "Athena workgroup whose monthly scanned bytes are capped."
  type        = string
}

variable "athena_monthly_bytes_limit" {
  description = "Month-to-date scanned bytes after which the Athena workgroup is disabled. 200 GiB is about $1 of scan at the current $5/TB rate."
  type        = number
  default     = 214748364800

  validation {
    condition     = var.athena_monthly_bytes_limit >= 1073741824 && floor(var.athena_monthly_bytes_limit) == var.athena_monthly_bytes_limit
    error_message = "athena_monthly_bytes_limit must be a whole number of at least one GiB."
  }
}

variable "dead_letter_queue_names" {
  description = "Dead-letter queues alarmed when any message arrives."
  type        = set(string)
  default     = []
}

variable "guard_role_arn" {
  description = "Bootstrap-owned execution role for the Athena spend guard."
  type        = string

  validation {
    condition     = var.guard_role_arn == "arn:aws:iam::${var.aws_account_id}:role/data-platform/runtime/${var.resource_prefix}-athena-guard"
    error_message = "guard_role_arn must be the exact environment Athena guard runtime role."
  }
}

variable "log_retention_days" {
  description = "Finite CloudWatch retention for the spend guard's own logs."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be a supported short CloudWatch retention value."
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
    error_message = "tags must identify the matching environment, Terraform, the data platform, and a non-empty owner."
  }
}
