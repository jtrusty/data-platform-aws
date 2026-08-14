variable "management_account_id" {
  description = "Organizations management account that hosts no platform workloads."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be a 12-digit AWS account ID."
  }
}

variable "workload_accounts" {
  description = "Workload environment names mapped to their dedicated AWS account IDs."
  type        = map(string)
}

variable "organization_admin_user_ids" {
  description = "Named Identity Center user IDs granted exceptional management-account access."
  type        = set(string)
}

variable "identity_center_instance_arn" {
  description = "Identity Center instance ARN. Null discovers the organization instance."
  type        = string
  default     = null
  nullable    = true
}

variable "identity_store_id" {
  description = "Identity Center identity store ID. Null uses the discovered instance's store."
  type        = string
  default     = null
  nullable    = true
}

variable "platform_admins_group_id" {
  description = "Existing PlatformAdmins Identity Center group ID."
  type        = string
  default     = null
  nullable    = true
}

variable "data_engineers_group_id" {
  description = "Existing DataEngineers Identity Center group ID."
  type        = string
  default     = null
  nullable    = true
}

# An organization trail covers every account in the organization and cannot be
# scoped to a subset. Set this to false where the platform does not own the
# whole organization.
variable "organization_trail" {
  description = "Create one organization-wide CloudTrail covering every account."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Address subscribed to management-account budget alerts. Supplied through a gitignored tfvars file; never committed to this public repository."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for the management account."
  type        = number
  default     = 25
}

variable "enable_security_hub" {
  description = "Enable Security Hub in the management account. Off until a measured bill justifies the per-check charge."
  type        = bool
  default     = false
}
