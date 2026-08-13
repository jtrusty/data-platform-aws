variable "aws_region" {
  description = "AWS region for the sandbox platform."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The data platform workload region is fixed to us-east-2."
  }
}

variable "aws_account_id" {
  description = "AWS account dedicated to the sandbox environment."
  type        = string
  default     = "555044956444"

  validation {
    condition     = var.aws_account_id == "555044956444"
    error_message = "Sandbox is fixed to AWS account 555044956444."
  }
}

variable "owner" {
  description = "Team or contact responsible for the platform."
  type        = string
  default     = "data-platform"

  validation {
    condition     = trimspace(var.owner) != ""
    error_message = "owner must not be empty."
  }
}
