variable "aws_account_id" {
  description = "AWS account the detective controls protect."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region the detective controls run in."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The data platform workload region is fixed to us-east-2."
  }
}

variable "environment" {
  description = "Environment identity used in detective resource names."
  type        = string

  validation {
    condition     = contains(["sandbox", "development", "production"], var.environment)
    error_message = "environment must be sandbox, development, or production."
  }
}

variable "resource_prefix" {
  description = "Environment-qualified data platform resource prefix."
  type        = string

  validation {
    condition     = var.resource_prefix == "data-platform-${var.environment}"
    error_message = "resource_prefix must equal data-platform-{environment}."
  }
}

variable "config_bucket_id" {
  description = "Bucket receiving AWS Config configuration snapshots and history."
  type        = string
}

variable "flow_log_bucket_arn" {
  description = "Bucket ARN receiving VPC flow log records."
  type        = string
}

variable "vpc_id" {
  description = "Analytics VPC whose traffic is recorded."
  type        = string
}

variable "config_recorder_role_arn" {
  description = "AWS Config service-linked role created by the account bootstrap."
  type        = string

  validation {
    condition     = var.config_recorder_role_arn == "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"
    error_message = "config_recorder_role_arn must be the account's AWS Config service-linked role."
  }
}

# Recording every supported type bills per configuration item for resources the
# platform does not own. This list covers the resources the security model
# actually depends on.
variable "config_resource_types" {
  description = "Resource types AWS Config records."
  type        = set(string)
  default = [
    "AWS::CloudTrail::Trail",
    "AWS::DynamoDB::Table",
    "AWS::EC2::SecurityGroup",
    "AWS::EC2::Subnet",
    "AWS::EC2::VPC",
    "AWS::IAM::Policy",
    "AWS::IAM::Role",
    "AWS::KMS::Key",
    "AWS::Lambda::Function",
    "AWS::S3::Bucket",
    "AWS::SQS::Queue",
  ]

  validation {
    condition     = length(var.config_resource_types) > 0
    error_message = "config_resource_types must record at least one resource type."
  }
}

variable "guardduty_publishing_frequency" {
  description = "How often GuardDuty publishes updated findings to downstream targets."
  type        = string
  default     = "SIX_HOURS"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_publishing_frequency)
    error_message = "guardduty_publishing_frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

# Security Hub bills per control check. It is the most expensive control in this
# module, so each environment decides independently.
variable "enable_security_hub" {
  description = "Enable Security Hub with the AWS Foundational Security Best Practices standard."
  type        = bool
  default     = true
}

variable "flow_log_traffic_type" {
  description = "Traffic recorded by VPC flow logs."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "ALL", "REJECT"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be ACCEPT, ALL, or REJECT."
  }
}

variable "tags" {
  description = "Mandatory data-platform boundary tags."
  type        = map(string)

  validation {
    condition = (
      lookup(var.tags, "Environment", "") == var.environment &&
      lookup(var.tags, "ManagedBy", "") == "terraform" &&
      lookup(var.tags, "Platform", "") == "data-platform" &&
      trimspace(lookup(var.tags, "Owner", "")) != ""
    )
    error_message = "tags must identify the matching environment, Terraform, the data platform, and a non-empty owner."
  }
}
