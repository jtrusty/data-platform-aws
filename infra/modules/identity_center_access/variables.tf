variable "instance_arn" {
  description = "Organization IAM Identity Center instance ARN."
  type        = string
  default     = "arn:aws:sso:::instance/ssoins-6684759f0418edd4"

  validation {
    condition     = var.instance_arn == "arn:aws:sso:::instance/ssoins-6684759f0418edd4"
    error_message = "instance_arn must match the confirmed organization instance."
  }
}

variable "identity_store_id" {
  description = "Organization IAM Identity Center identity store ID."
  type        = string
  default     = "d-9a675d55f3"

  validation {
    condition     = var.identity_store_id == "d-9a675d55f3"
    error_message = "identity_store_id must match the confirmed identity store."
  }
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
  description = "PlatformAdmins Identity Center group ID."
  type        = string
  default     = "118b3590-f061-7088-bff1-cc1c9f78d5c3"
}

variable "data_engineers_group_id" {
  description = "DataEngineers Identity Center group ID."
  type        = string
  default     = "619b5560-5001-707a-8057-b239ffbd3ae1"
}
