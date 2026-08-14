locals {
  bucket_name              = "jtrusty-dp-audit-${var.management_account_id}-us-east-2"
  topic_name               = "jtrusty-data-platform-organization-alerts"
  topic_arn                = "arn:aws:sns:us-east-2:${var.management_account_id}:jtrusty-data-platform-organization-alerts"
  config_prefix            = "config"
  bucket_arn               = "arn:aws:s3:::${local.bucket_name}"
  trail_arn                = "arn:aws:cloudtrail:us-east-2:${var.management_account_id}:trail/${var.trail_name}"
  config_recorder_role_arn = "arn:aws:iam::${var.management_account_id}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"

  # An organization trail writes member logs under the organization ID; separate
  # per-account trails write under each account ID. Both always include the
  # management account's own path.
  trail_write_resources = concat(
    ["${local.bucket_arn}/AWSLogs/${var.management_account_id}/*"],
    var.organization_trail
    ? ["${local.bucket_arn}/AWSLogs/${data.aws_organizations_organization.current.id}/*"]
    : [for account_id in var.member_account_ids : "${local.bucket_arn}/AWSLogs/${account_id}/*"],
  )

  trail_source_arns = concat(
    [local.trail_arn],
    var.organization_trail ? [] : [for account_id in var.member_account_ids : "arn:aws:cloudtrail:us-east-2:${account_id}:trail/${var.trail_name}"],
  )
}

data "aws_organizations_organization" "current" {}

resource "aws_s3_bucket" "audit" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = merge(var.tags, { Purpose = "organization-audit" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket = aws_s3_bucket.audit.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# CloudTrail delivers with SSE-S3 at no additional cost. A customer-managed key
# would add a fixed monthly charge for a low-value-at-rest audit copy whose
# integrity is already protected by log file validation, and the bucket is
# unreadable outside the management account regardless of key ownership.
#trivy:ignore:AVD-AWS-0132:exp:2027-08-13
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    id     = "expire-audit-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.audit]
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "AWSConfigAclCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = local.bucket_arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.management_account_id }
        }
      },
      {
        Sid       = "AWSConfigWrite"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/${local.config_prefix}/*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.management_account_id }
        }
      },
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = local.bucket_arn
        Condition = {
          StringEquals = { "aws:SourceArn" = local.trail_arn }
        }
      },
      # An organization trail delivers member-account logs under the organization
      # ID and the management account's own logs under its account ID, and
      # CreateTrail rejects a policy that is missing either path.
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = local.trail_write_resources
        Condition = {
          StringEquals = { "aws:SourceArn" = local.trail_source_arns }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.audit]
}

# One organization-wide trail recording management events in every region. The
# first copy of management events is free; only S3 storage is billed, and that
# storage is capped by the lifecycle rule above. A customer-managed key for the
# trail is a deliberate cost tradeoff, reviewed with the SSE-S3 note above.
#trivy:ignore:AVD-AWS-0015:exp:2027-08-13
resource "aws_cloudtrail" "organization" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.audit.id
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = var.organization_trail
  tags                          = merge(var.tags, { Purpose = "organization-audit" })

  dynamic "event_selector" {
    for_each = length(var.state_bucket_data_events) == 0 ? [] : [var.state_bucket_data_events]

    content {
      include_management_events = true
      read_write_type           = "All"

      data_resource {
        type   = "AWS::S3::Object"
        values = [for arn in event_selector.value : "${arn}/"]
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.audit]
}

resource "aws_iam_service_linked_role" "detection" {
  for_each = var.manage_detective_service_linked_roles ? toset(["config.amazonaws.com", "guardduty.amazonaws.com", "securityhub.amazonaws.com"]) : toset([])

  aws_service_name = each.value

  lifecycle {
    prevent_destroy = true
  }
}

# Alerts carry no sensitive data, and the AWS-managed SNS key has no monthly
# charge where a customer-managed key would add one per account.
#trivy:ignore:AVD-AWS-0136:exp:2027-08-13
resource "aws_sns_topic" "alerts" {
  name              = local.topic_name
  kms_master_key_id = "alias/aws/sns"
  tags              = merge(var.tags, { Purpose = "organization-alerts" })
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountOwnerAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.management_account_id}:root" }
        Action    = ["sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:Subscribe", "sns:Publish", "sns:ListSubscriptionsByTopic"]
        Resource  = local.topic_arn
      },
      {
        Sid       = "AllowBudgetPublishing"
        Effect    = "Allow"
        Principal = { Service = "budgets.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = local.topic_arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.management_account_id }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "sns:Publish"
        Resource  = local.topic_arn
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

resource "aws_sns_topic_subscription" "alert_email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_budgets_budget" "management" {
  name         = "jtrusty-data-platform-management-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = toset([50, 80, 100])

    content {
      comparison_operator       = "GREATER_THAN"
      notification_type         = "ACTUAL"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
    }
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    notification_type         = "FORECASTED"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  depends_on = [aws_sns_topic_policy.alerts]
}

resource "aws_guardduty_detector" "management" {
  enable                       = true
  finding_publishing_frequency = "SIX_HOURS"
  tags                         = merge(var.tags, { Purpose = "threat-detection" })

  depends_on = [aws_iam_service_linked_role.detection]
}

resource "aws_config_configuration_recorder" "management" {
  name     = "jtrusty-data-platform-management-recorder"
  role_arn = local.config_recorder_role_arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = var.config_resource_types
  }

  depends_on = [aws_iam_service_linked_role.detection]
}

resource "aws_config_delivery_channel" "management" {
  name           = "jtrusty-data-platform-management-delivery"
  s3_bucket_name = aws_s3_bucket.audit.id
  s3_key_prefix  = local.config_prefix

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.management, aws_s3_bucket_policy.audit]
}

resource "aws_config_configuration_recorder_status" "management" {
  name       = aws_config_configuration_recorder.management.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.management]
}

resource "aws_securityhub_account" "management" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true

  depends_on = [aws_iam_service_linked_role.detection]
}

resource "aws_securityhub_standards_subscription" "foundational" {
  count = var.enable_security_hub ? 1 : 0

  standards_arn = "arn:aws:securityhub:us-east-2::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.management]
}
