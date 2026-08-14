variable "bucket_name" {
  description = "Globally unique name for the platform bucket."
  type        = string

  validation {
    condition = (
      can(regex("^data-platform-[a-z0-9][a-z0-9.-]{2,47}[a-z0-9]$", var.bucket_name)) &&
      !strcontains(var.bucket_name, "..") &&
      alltrue([
        for suffix in ["-s3alias", "--ol-s3", ".mrap", "--x-s3", "--table-s3"] :
        !endswith(var.bucket_name, suffix)
      ])
    )
    error_message = "bucket_name must be an 18-63 character, DNS-safe data-platform-* name without adjacent periods or an AWS-reserved suffix."
  }
}

variable "kms_key_arn" {
  description = "Optional ARN of the platform KMS key. Null uses no-additional-cost SSE-S3 encryption."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.kms_key_arn == null ? true : (
      can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.kms_key_arn)) ||
      can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/mrk-[0-9a-fA-F]{32}$", var.kms_key_arn))
    )
    error_message = "kms_key_arn must be null or a canonical single-Region or multi-Region KMS key ARN, not an alias or unrestricted value."
  }
}

variable "versioning_enabled" {
  description = "Enable object versioning where recovery needs justify the additional storage."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket. Keep false outside disposable tests."
  type        = bool
  default     = false
}

variable "noncurrent_expiration" {
  description = "Days to retain noncurrent object versions."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_expiration >= 7 && var.noncurrent_expiration <= 3650
    error_message = "noncurrent_expiration must be between 7 days and 10 years."
  }
}

variable "current_expiration" {
  description = "Optional number of days after which current objects expire. Null retains current objects."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.current_expiration == null ? true : var.current_expiration >= 1 && var.current_expiration <= 3650
    error_message = "current_expiration must be null or between 1 day and 10 years."
  }
}

variable "log_delivery" {
  description = "Optional AWS log-delivery grant. AWS Config and VPC flow logs write with the service's own credentials, so the bucket policy must name the service principal and the owning account."
  type = object({
    account_id        = string
    service_principal = string
    prefix            = optional(string, "")
  })
  default  = null
  nullable = true

  validation {
    condition = var.log_delivery == null ? true : (
      can(regex("^[0-9]{12}$", var.log_delivery.account_id)) &&
      contains(["config.amazonaws.com", "delivery.logs.amazonaws.com"], var.log_delivery.service_principal)
    )
    error_message = "log_delivery must name a 12-digit account and either the AWS Config or the log delivery service principal."
  }
}

variable "tags" {
  description = "Resource tags. The platform boundary tags are mandatory."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Environment", "ManagedBy", "Owner", "Platform"] :
      contains(keys(var.tags), key) && trimspace(lookup(var.tags, key, "")) != ""
    ])
    error_message = "tags must contain non-empty Environment, ManagedBy, Owner, and Platform values."
  }

  validation {
    condition     = lookup(var.tags, "ManagedBy", "") == "terraform" && lookup(var.tags, "Platform", "") == "data-platform"
    error_message = "ManagedBy must be terraform and Platform must be data-platform."
  }
}
