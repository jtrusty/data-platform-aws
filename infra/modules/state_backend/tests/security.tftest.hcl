mock_provider "aws" {}

variables {
  account_id  = "555044956444"
  environment = "sandbox"
  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "secure_state_backend" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "jtrusty-dp-tfstate-sandbox-555044956444-us-east-2"
    error_message = "The state bucket must use the protected, environment-specific namespace."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All S3 Block Public Access controls must be enabled."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "State bucket ACLs must be disabled."
  }

  assert {
    condition     = one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
    error_message = "State versioning is required for recovery."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "State must use KMS encryption."
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation && aws_kms_key.this.deletion_window_in_days >= 30
    error_message = "The state KMS key must rotate and have a recovery window."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Effect == "Deny" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    )
    error_message = "State access without TLS must be denied."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_s3_bucket_policy.this.policy).Statement : statement if statement.Sid == "DenyNonKMSStateUploads"]).Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "aws:kms" &&
      one([for statement in jsondecode(aws_s3_bucket_policy.this.policy).Statement : statement if statement.Sid == "DenyWrongStateKey"]).Condition.StringNotEquals["s3:x-amz-server-side-encryption-aws-kms-key-id"] == "arn:aws:kms:us-east-2:555044956444:alias/jtrusty-data-platform-tfstate-sandbox"
    )
    error_message = "Every state upload must request the exact environment KMS alias."
  }

  assert {
    condition     = !aws_s3_bucket.this.force_destroy
    error_message = "State buckets must not be force-destroyable."
  }
}

run "organization_bucket_name_is_valid" {
  command = plan

  variables {
    account_id  = "699599381258"
    environment = "organization"
  }

  assert {
    condition     = length(aws_s3_bucket.this.bucket) <= 63
    error_message = "The organization state bucket must satisfy the S3 63-character limit."
  }
}

run "development_bucket_name_is_valid" {
  command = plan

  variables {
    account_id  = "511492912574"
    environment = "development"
  }

  assert {
    condition     = length(aws_s3_bucket.this.bucket) <= 63
    error_message = "The development state bucket must satisfy the S3 63-character limit."
  }
}

run "production_bucket_name_is_valid" {
  command = plan

  variables {
    account_id  = "991278600180"
    environment = "production"
  }

  assert {
    condition     = length(aws_s3_bucket.this.bucket) <= 63
    error_message = "The production state bucket must satisfy the S3 63-character limit."
  }
}

run "reject_management_as_workload" {
  command = plan

  variables {
    account_id = "699599381258"
  }

  expect_failures = [var.account_id]
}
