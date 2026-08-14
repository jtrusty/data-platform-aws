variable "account_id" {
  description = "Exact workload account ID."
  type        = string

  validation {
    condition = contains([
      "555044956444",
      "511492912574",
      "991278600180",
    ], var.account_id)
    error_message = "account_id must be one of the three approved workload accounts."
  }
}

variable "environment" {
  description = "Exact workload environment."
  type        = string

  validation {
    condition = lookup({
      sandbox     = "555044956444"
      development = "511492912574"
      production  = "991278600180"
    }, var.environment, null) == var.account_id
    error_message = "environment and account_id must match the approved account map."
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
  default     = "jtrusty"

  validation {
    condition     = var.github_repository_owner == "jtrusty"
    error_message = "Only the jtrusty repository owner is approved."
  }
}

variable "github_owner_id" {
  description = "Immutable GitHub repository owner ID."
  type        = string
  default     = "6896625"

  validation {
    condition     = var.github_owner_id == "6896625"
    error_message = "github_owner_id must match the verified repository owner ID."
  }
}

variable "github_repository_name" {
  description = "Immutable GitHub repository name component."
  type        = string
  default     = "data-platform-aws"

  validation {
    condition     = var.github_repository_name == "data-platform-aws"
    error_message = "Only jtrusty/data-platform-aws is approved for deployment."
  }
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID."
  type        = string
  default     = "1333254672"

  validation {
    condition     = var.github_repository_id == "1333254672"
    error_message = "github_repository_id must match the verified repository ID."
  }
}

variable "manage_redshift_service_linked_role" {
  description = "Create the account-wide Redshift service-linked role. Set to false for an account where it already exists; an existing managed role must be removed from state rather than destroyed."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Mandatory bootstrap ownership tags."
  type        = map(string)
}
