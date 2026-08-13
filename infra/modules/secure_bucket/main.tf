resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
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

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = var.kms_key_arn != null

    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    dynamic "expiration" {
      for_each = var.current_expiration == null ? [] : [var.current_expiration]

      content {
        days = expiration.value
      }
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expiration
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
    Statement = concat(
      [{
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }],
      [{
        Sid       = "DenyExplicitWrongEncryption"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${var.bucket_name}/*"
        Condition = {
          Null = {
            "s3:x-amz-server-side-encryption" = "false"
          }
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = var.kms_key_arn == null ? "AES256" : "aws:kms"
          }
        }
      }],
      var.kms_key_arn == null ? [] : [
        {
          Sid       = "DenyExplicitMissingKmsKey"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:PutObject"
          Resource  = "arn:aws:s3:::${var.bucket_name}/*"
          Condition = {
            StringEquals = {
              "s3:x-amz-server-side-encryption" = "aws:kms"
            }
            Null = {
              "s3:x-amz-server-side-encryption-aws-kms-key-id" = "true"
            }
          }
        },
        {
          Sid       = "DenyExplicitWrongKmsKey"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:PutObject"
          Resource  = "arn:aws:s3:::${var.bucket_name}/*"
          Condition = {
            Null = {
              "s3:x-amz-server-side-encryption-aws-kms-key-id" = "false"
            }
            StringNotEquals = {
              "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.kms_key_arn
            }
          }
        },
      ],
    )
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
