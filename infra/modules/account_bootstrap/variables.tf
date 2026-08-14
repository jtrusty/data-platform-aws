variable "account_id" {
  description = "Exact workload account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "environment" {
  description = "Exact workload environment."
  type        = string

  validation {
    condition     = contains(["sandbox", "development", "production"], var.environment)
    error_message = "environment must be sandbox, development, or production."
  }
}

variable "github_environment" {
  description = "GitHub Environment allowed to assume the deployment role."
  type        = string

  validation {
    condition     = var.github_environment == var.environment
    error_message = "The deployment GitHub Environment must exactly match the workload environment."
  }
}

variable "github_repository_owner" {
  description = "Immutable GitHub repository owner name component."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,38}$", var.github_repository_owner))
    error_message = "github_repository_owner must be a valid GitHub owner name."
  }
}

variable "github_owner_id" {
  description = "Immutable GitHub identifier component."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be the numeric GitHub owner ID."
  }
}

variable "github_repository_name" {
  description = "Immutable GitHub repository name component."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,100}$", var.github_repository_name))
    error_message = "github_repository_name must be a valid GitHub repository name."
  }
}

variable "github_repository_id" {
  description = "Immutable GitHub identifier component."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be the numeric GitHub repository ID."
  }
}

variable "manage_redshift_service_linked_role" {
  description = "Create the account-wide Redshift service-linked role. Set to false for an account where it already exists; an existing managed role must be removed from state rather than destroyed."
  type        = bool
  default     = true
}

variable "manage_detective_service_linked_roles" {
  description = "Create the account-wide AWS Config, GuardDuty, and Security Hub service-linked roles. Set to false for an account where they already exist."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Mandatory bootstrap ownership tags."
  type        = map(string)
}
