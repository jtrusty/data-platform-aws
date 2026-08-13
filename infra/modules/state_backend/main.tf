locals {
  bucket_name   = "jtrusty-dp-tfstate-${var.environment}-${var.account_id}-us-east-2"
  bucket_arn    = "arn:aws:s3:::${local.bucket_name}"
  kms_alias_arn = "arn:aws:kms:us-east-2:${var.account_id}:alias/jtrusty-data-platform-tfstate-${var.environment}"
}

resource "aws_kms_key" "this" {
  description             = "Terraform state encryption for data platform ${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = merge(var.tags, { Purpose = "terraform-state" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/jtrusty-data-platform-tfstate-${var.environment}"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = merge(var.tags, { Purpose = "terraform-state" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.this.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "retain-state-history"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.environment == "production" ? 730 : 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          local.bucket_arn,
          "${local.bucket_arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyExplicitNonKMSUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/*"
        # Headerless Terraform state and lock uploads use the enforced bucket
        # default. An explicitly requested weaker algorithm is denied.
        Condition = {
          Null            = { "s3:x-amz-server-side-encryption" = "false" }
          StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" }
        }
      },
      {
        Sid       = "DenyExplicitWrongKMSKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/*"
        Condition = {
          Null = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = "false" }
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = [
              local.kms_alias_arn,
              aws_kms_key.this.arn,
            ]
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
