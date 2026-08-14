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

  validation {
    condition = (
      alltrue([for account_id in values(var.workload_accounts) : can(regex("^[0-9]{12}$", account_id))]) &&
      length(distinct(values(var.workload_accounts))) == length(var.workload_accounts)
    )
    error_message = "Every workload environment needs its own distinct 12-digit AWS account."
  }

  validation {
    condition     = contains(keys(var.workload_accounts), "production")
    error_message = "workload_accounts must include a production environment."
  }
}

variable "instance_arn" {
  description = "Identity Center instance ARN. Null discovers the organization instance, which cannot be created by Terraform and must already be enabled."
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

variable "organization_admin_user_ids" {
  description = "Named Identity Center user IDs granted exceptional management-account access."
  type        = set(string)

  validation {
    condition     = length(var.organization_admin_user_ids) > 0 && length(var.organization_admin_user_ids) <= 2
    error_message = "Provide one or two named organization administrator user IDs."
  }
}

variable "platform_admins_group_id" {
  description = "Existing PlatformAdmins group ID. Ignored when create_groups is true."
  type        = string
  default     = null
  nullable    = true
}

variable "data_engineers_group_id" {
  description = "Existing DataEngineers group ID. Ignored when create_groups is true."
  type        = string
  default     = null
  nullable    = true
}

# An existing organization may already use these names, so both the permission
# sets and the customer-managed policies they reference can be namespaced.
variable "permission_set_prefix" {
  description = "Prefix applied to every managed permission set name."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{0,16}$", var.permission_set_prefix))
    error_message = "permission_set_prefix must be up to 16 name-safe characters."
  }
}

variable "human_policy_prefix" {
  description = "Prefix of the account-level customer-managed policies attached to the DataEngineer permission sets."
  type        = string
  default     = "jtrusty-data-platform"
}

variable "create_groups" {
  description = "Create the PlatformAdmins and DataEngineers groups instead of using existing group IDs."
  type        = bool
  default     = false
}

variable "platform_admins_group_name" {
  description = "Display name used when creating or documenting the platform administrators group."
  type        = string
  default     = "PlatformAdmins"
}

variable "data_engineers_group_name" {
  description = "Display name used when creating or documenting the data engineers group."
  type        = string
  default     = "DataEngineers"
}
