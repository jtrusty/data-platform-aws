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
  description = "ARN of the platform KMS key used for default bucket encryption."
  type        = string

  validation {
    condition = (
      can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.kms_key_arn)) ||
      can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/mrk-[0-9a-fA-F]{32}$", var.kms_key_arn))
    )
    error_message = "kms_key_arn must be a canonical single-Region or multi-Region KMS key ARN, not an alias or unrestricted value."
  }
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
