mock_provider "aws" {}

variables {
  aws_account_id           = "555044956444"
  environment              = "sandbox"
  resource_prefix          = "data-platform-sandbox"
  config_bucket_id         = "data-platform-sandbox-config-555044956444"
  flow_log_bucket_arn      = "arn:aws:s3:::data-platform-sandbox-flow-logs-555044956444"
  vpc_id                   = "vpc-00000000000000000"
  config_recorder_role_arn = "arn:aws:iam::555044956444:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"
  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "detection_is_enabled_and_bounded" {
  command = plan

  assert {
    condition     = aws_guardduty_detector.platform.enable
    error_message = "GuardDuty must be enabled."
  }

  # Recording every supported type bills per configuration item for resources
  # the platform does not own.
  assert {
    condition = (
      !one(aws_config_configuration_recorder.platform.recording_group).all_supported &&
      !one(aws_config_configuration_recorder.platform.recording_group).include_global_resource_types &&
      length(one(aws_config_configuration_recorder.platform.recording_group).resource_types) == 11
    )
    error_message = "AWS Config must record a bounded, explicit list of resource types."
  }

  assert {
    condition = (
      aws_config_delivery_channel.platform.s3_bucket_name == var.config_bucket_id &&
      one(aws_config_delivery_channel.platform.snapshot_delivery_properties).delivery_frequency == "TwentyFour_Hours"
    )
    error_message = "Config snapshots must land in the platform config bucket at the cheapest useful frequency."
  }

  # S3 delivery avoids per-GB CloudWatch Logs ingestion charges.
  assert {
    condition = (
      aws_flow_log.analytics.log_destination_type == "s3" &&
      aws_flow_log.analytics.vpc_id == var.vpc_id &&
      aws_flow_log.analytics.max_aggregation_interval == 600
    )
    error_message = "VPC flow logs must be delivered to S3 with the coarser aggregation interval."
  }

  # Security Hub is billed per control check and stays off until a measured bill
  # justifies it. The rest of detection does not depend on it.
  assert {
    condition = (
      length(aws_securityhub_account.platform) == 0 &&
      length(aws_securityhub_standards_subscription.foundational) == 0
    )
    error_message = "Security Hub must stay off by default."
  }
}

run "security_hub_can_be_enabled" {
  command = plan

  variables {
    enable_security_hub = true
  }

  assert {
    condition = (
      length(aws_securityhub_account.platform) == 1 &&
      length(aws_securityhub_standards_subscription.foundational) == 1 &&
      endswith(one(aws_securityhub_standards_subscription.foundational).standards_arn, "aws-foundational-security-best-practices/v/1.0.0") &&
      aws_guardduty_detector.platform.enable
    )
    error_message = "When enabled, Security Hub must subscribe exactly the foundational standard."
  }
}

run "reject_foreign_config_role" {
  command = plan

  variables {
    config_recorder_role_arn = "arn:aws:iam::555044956444:role/data-platform/runtime/data-platform-sandbox-ingest"
  }

  expect_failures = [var.config_recorder_role_arn]
}
