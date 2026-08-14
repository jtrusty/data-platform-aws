variable "management_account_id" {
  description = "Organizations management account that owns the organization trail."
  type        = string
  default     = "699599381258"

  validation {
    condition     = var.management_account_id == "699599381258"
    error_message = "The organization trail is fixed to management account 699599381258."
  }
}

variable "trail_name" {
  description = "Organization CloudTrail name."
  type        = string
  default     = "jtrusty-data-platform-organization"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9._-]{2,127}$", var.trail_name))
    error_message = "trail_name must be a valid CloudTrail name."
  }
}

variable "log_retention_days" {
  description = "Days to retain organization CloudTrail objects; storage is the only recurring cost of this trail."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 3650 && floor(var.log_retention_days) == var.log_retention_days
    error_message = "log_retention_days must be a whole number from 30 through 3650."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain overwritten or deleted audit-log versions."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 7 && var.noncurrent_version_expiration_days <= 365
    error_message = "noncurrent_version_expiration_days must be between 7 and 365."
  }
}

# Management events are free for the first copy per account. Data events are
# billed per event and stay off unless an investigation needs object-level
# state access history.
variable "state_bucket_data_events" {
  description = "Terraform state bucket ARNs to record S3 object-level data events for; billed per event, empty by default."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.state_bucket_data_events : can(regex("^arn:aws:s3:::jtrusty-dp-tfstate-[a-z]+-[0-9]{12}-us-east-2$", arn))])
    error_message = "state_bucket_data_events must contain only jtrusty-dp-tfstate-* bucket ARNs."
  }
}

variable "alert_email" {
  description = "Address subscribed to management-account budget alerts. Supplied out of band; never committed."
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
  description = "Monthly cost budget for the management account."
  type        = number
  default     = 25

  validation {
    condition     = var.monthly_budget_usd >= 1 && var.monthly_budget_usd <= 1000
    error_message = "monthly_budget_usd must be between 1 and 1000."
  }
}

variable "enable_security_hub" {
  description = "Enable Security Hub with the foundational standard in the management account. Off by default because it is billed per control check."
  type        = bool
  default     = false
}

variable "manage_detective_service_linked_roles" {
  description = "Create the management account's Config, GuardDuty, and Security Hub service-linked roles."
  type        = bool
  default     = true
}

variable "config_resource_types" {
  description = "Resource types AWS Config records in the management account."
  type        = set(string)
  default = [
    "AWS::CloudTrail::Trail",
    "AWS::IAM::Policy",
    "AWS::IAM::Role",
    "AWS::KMS::Key",
    "AWS::S3::Bucket",
  ]
}

variable "tags" {
  description = "Mandatory organization audit tags."
  type        = map(string)

  validation {
    condition = (
      lookup(var.tags, "ManagedBy", "") == "terraform" &&
      lookup(var.tags, "Platform", "") == "data-platform" &&
      trimspace(lookup(var.tags, "Owner", "")) != ""
    )
    error_message = "tags must identify Terraform, the data platform, and a non-empty owner."
  }
}
