variable "account_id" {
  description = "AWS account that owns this environment's Terraform state."
  type        = string

  validation {
    condition = lookup({
      organization = "699599381258"
      sandbox      = "555044956444"
      development  = "511492912574"
      production   = "991278600180"
    }, var.environment, null) == var.account_id
    error_message = "account_id and environment must match the approved organization account map."
  }
}

variable "environment" {
  description = "Fixed workload environment name."
  type        = string

  validation {
    condition     = contains(["organization", "sandbox", "development", "production"], var.environment)
    error_message = "environment must be organization, sandbox, development, or production."
  }
}

variable "tags" {
  description = "Mandatory ownership tags for bootstrap resources."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Environment", "ManagedBy", "Owner", "Platform"] :
      contains(keys(var.tags), key) && trimspace(lookup(var.tags, key, "")) != ""
    ])
    error_message = "tags must include Environment, ManagedBy, Owner, and Platform."
  }
}
