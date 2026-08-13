variable "aws_region" {
  description = "AWS region for the production platform."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The data platform workload region is fixed to us-east-2."
  }
}

variable "aws_account_id" {
  description = "AWS account dedicated to the production environment."
  type        = string
  default     = "991278600180"

  validation {
    condition     = var.aws_account_id == "991278600180"
    error_message = "Production is fixed to AWS account 991278600180."
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
