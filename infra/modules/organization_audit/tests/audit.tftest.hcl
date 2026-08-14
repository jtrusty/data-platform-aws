mock_provider "aws" {
  mock_data "aws_organizations_organization" {
    defaults = {
      id = "o-000000000000"
    }
  }
}

variables {
  management_account_id = "699599381258"
  tags = {
    Environment = "organization"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "organization_trail_is_complete_and_cheap" {
  command = plan

  assert {
    condition = (
      aws_cloudtrail.organization.is_organization_trail &&
      aws_cloudtrail.organization.is_multi_region_trail &&
      aws_cloudtrail.organization.include_global_service_events &&
      aws_cloudtrail.organization.enable_log_file_validation
    )
    error_message = "The organization trail must cover every account and region with tamper-evident logs."
  }

  assert {
    condition     = length(aws_cloudtrail.organization.event_selector) == 0
    error_message = "Per-event billed data events must stay off unless explicitly requested."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.audit.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Audit logs must use no-additional-cost SSE-S3 encryption."
  }

  assert {
    condition     = one(one(aws_s3_bucket_lifecycle_configuration.audit.rule).expiration).days == 365
    error_message = "Audit storage must expire so idle cost stays bounded."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.audit.block_public_acls,
      aws_s3_bucket_public_access_block.audit.block_public_policy,
      aws_s3_bucket_public_access_block.audit.ignore_public_acls,
      aws_s3_bucket_public_access_block.audit.restrict_public_buckets,
    ])
    error_message = "All S3 Block Public Access controls must be enabled on the audit bucket."
  }

  assert {
    condition     = !aws_s3_bucket.audit.force_destroy
    error_message = "The audit bucket must not be force-destroyable."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_s3_bucket_policy.audit.policy).Statement : statement if statement.Sid == "DenyInsecureTransport"]).Effect == "Deny" &&
      toset(one([for statement in jsondecode(aws_s3_bucket_policy.audit.policy).Statement : statement if statement.Sid == "AWSCloudTrailWrite"]).Condition.StringEquals["aws:SourceArn"]) == toset(["arn:aws:cloudtrail:us-east-2:699599381258:trail/jtrusty-data-platform-organization"]) &&
      toset(one([for statement in jsondecode(aws_s3_bucket_policy.audit.policy).Statement : statement if statement.Sid == "AWSCloudTrailWrite"]).Resource) == toset([
        "arn:aws:s3:::jtrusty-dp-audit-699599381258-us-east-2/AWSLogs/699599381258/*",
        "arn:aws:s3:::jtrusty-dp-audit-699599381258-us-east-2/AWSLogs/o-000000000000/*",
      ])
    )
    error_message = "Only this organization trail may write audit objects, and only over TLS."
  }
}

run "optional_state_data_events_are_scoped" {
  command = plan

  variables {
    state_bucket_data_events = ["arn:aws:s3:::jtrusty-dp-tfstate-production-991278600180-us-east-2"]
  }

  assert {
    condition     = one(one(aws_cloudtrail.organization.event_selector).data_resource).values == tolist(["arn:aws:s3:::jtrusty-dp-tfstate-production-991278600180-us-east-2/"])
    error_message = "Data events must be limited to the requested Terraform state buckets."
  }
}

run "reject_unrelated_data_event_buckets" {
  command = plan

  variables {
    state_bucket_data_events = ["arn:aws:s3:::data-platform-production-silver-991278600180"]
  }

  expect_failures = [var.state_bucket_data_events]
}

# An organization that does not own every account in its organization audits
# only the platform accounts, each delivering its own trail into this bucket.
run "member_account_trails_replace_the_organization_trail" {
  command = plan

  variables {
    organization_trail = false
    member_account_ids = ["555044956444", "511492912574"]
  }

  assert {
    condition     = !aws_cloudtrail.organization.is_organization_trail
    error_message = "Scoped auditing must not create an organization-wide trail."
  }

  assert {
    condition = toset(one([for statement in jsondecode(aws_s3_bucket_policy.audit.policy).Statement : statement if statement.Sid == "AWSCloudTrailWrite"]).Resource) == toset([
      "arn:aws:s3:::jtrusty-dp-audit-699599381258-us-east-2/AWSLogs/699599381258/*",
      "arn:aws:s3:::jtrusty-dp-audit-699599381258-us-east-2/AWSLogs/555044956444/*",
      "arn:aws:s3:::jtrusty-dp-audit-699599381258-us-east-2/AWSLogs/511492912574/*",
    ])
    error_message = "Only the named member accounts may deliver trails into the audit bucket."
  }

  assert {
    condition = toset(one([for statement in jsondecode(aws_s3_bucket_policy.audit.policy).Statement : statement if statement.Sid == "AWSCloudTrailWrite"]).Condition.StringEquals["aws:SourceArn"]) == toset([
      "arn:aws:cloudtrail:us-east-2:699599381258:trail/jtrusty-data-platform-organization",
      "arn:aws:cloudtrail:us-east-2:555044956444:trail/jtrusty-data-platform-organization",
      "arn:aws:cloudtrail:us-east-2:511492912574:trail/jtrusty-data-platform-organization",
    ])
    error_message = "Each authorized trail must be named exactly, not left open to any trail in the account."
  }
}

run "reject_malformed_member_account" {
  command = plan

  variables {
    organization_trail = false
    member_account_ids = ["not-an-account"]
  }

  expect_failures = [var.member_account_ids]
}
