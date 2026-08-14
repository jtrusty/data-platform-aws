variable "account_id" {
  description = "AWS account this bootstrap root owns."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "github_repository_owner" {
  description = "GitHub owner allowed to assume the deployment role."
  type        = string
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID."
  type        = string
}

variable "github_repository_name" {
  description = "GitHub repository allowed to assume the deployment role."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string
}
