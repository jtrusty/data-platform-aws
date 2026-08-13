mock_provider "aws" {}

variables {
  bucket_name           = "data-platform-sandbox-test-123456789012"
  kms_key_arn           = "arn:aws:kms:us-east-2:123456789012:key/00000000-0000-0000-0000-000000000000"
  noncurrent_expiration = 30
  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "secure_bucket_defaults" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls
    error_message = "Public ACLs must be blocked."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy
    error_message = "Public bucket policies must be blocked."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls
    error_message = "Public ACLs must be ignored."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "Public buckets must be restricted."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled with BucketOwnerEnforced ownership."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "The bucket must use KMS encryption."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).kms_master_key_id == var.kms_key_arn
    error_message = "The bucket must use the supplied platform KMS key."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled
    error_message = "S3 Bucket Keys must be enabled to control KMS request cost."
  }

  assert {
    condition     = one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
    error_message = "Versioning must be enabled."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_s3_bucket_policy.this.policy).Statement :
      statement.Sid == "DenyExplicitMissingKmsKey" &&
      statement.Condition.StringEquals["s3:x-amz-server-side-encryption"] == "aws:kms" &&
      statement.Condition.Null["s3:x-amz-server-side-encryption-aws-kms-key-id"] == "true"
    ])
    error_message = "An explicit aws:kms upload must name the bucket's configured customer-managed key."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Effect == "Deny" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Principal == "*" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Action == "s3:*" &&
      toset(jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Resource) == toset([
        "arn:aws:s3:::${var.bucket_name}",
        "arn:aws:s3:::${var.bucket_name}/*",
      ]) &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    )
    error_message = "The bucket policy must deny every principal's S3 requests when TLS is not used."
  }

  assert {
    condition = (
      one(aws_s3_bucket_lifecycle_configuration.this.rule).status == "Enabled" &&
      one(one(aws_s3_bucket_lifecycle_configuration.this.rule).noncurrent_version_expiration).noncurrent_days == var.noncurrent_expiration &&
      one(one(aws_s3_bucket_lifecycle_configuration.this.rule).abort_incomplete_multipart_upload).days_after_initiation == 7
    )
    error_message = "Lifecycle rules must expire noncurrent versions and abandoned multipart uploads."
  }

  assert {
    condition     = !aws_s3_bucket.this.force_destroy
    error_message = "Buckets must be protected from accidental deletion by default."
  }

  assert {
    condition     = alltrue([for key, value in var.tags : aws_s3_bucket.this.tags[key] == value])
    error_message = "Every mandatory platform-boundary tag must be applied to the bucket."
  }
}

run "reject_unbounded_lifecycle" {
  command = plan

  variables {
    noncurrent_expiration = 0
  }

  expect_failures = [var.noncurrent_expiration]
}

run "aws_managed_encryption_avoids_a_monthly_kms_key" {
  command = plan

  variables {
    kms_key_arn = null
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Buckets must support SSE-S3 as the no-additional-cost encryption default."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_s3_bucket_policy.this.policy).Statement :
      statement.Sid == "DenyExplicitWrongEncryption" &&
      statement.Effect == "Deny" &&
      statement.Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "AES256"
    ])
    error_message = "SSE-S3 buckets must reject an explicitly requested weaker or alternate encryption mode."
  }

}
