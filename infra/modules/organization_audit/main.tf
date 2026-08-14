locals {
  bucket_name = "jtrusty-dp-audit-${var.management_account_id}-us-east-2"
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"
  trail_arn   = "arn:aws:cloudtrail:us-east-2:${var.management_account_id}:trail/${var.trail_name}"
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
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = local.bucket_arn
        Condition = {
          StringEquals = { "aws:SourceArn" = local.trail_arn }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/AWSLogs/${data.aws_organizations_organization.current.id}/*"
        Condition = {
          StringEquals = { "aws:SourceArn" = local.trail_arn }
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
  is_organization_trail         = true
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
