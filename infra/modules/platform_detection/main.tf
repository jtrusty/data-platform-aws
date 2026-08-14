locals {
  config_prefix = "config"
}

# GuardDuty is priced per million analyzed CloudTrail events and per GB of
# analyzed logs, so an idle account costs approximately nothing.
resource "aws_guardduty_detector" "platform" {
  enable                       = true
  finding_publishing_frequency = var.guardduty_publishing_frequency
  tags                         = merge(var.tags, { Purpose = "threat-detection" })
}

resource "aws_config_configuration_recorder" "platform" {
  name     = "${var.resource_prefix}-recorder"
  role_arn = var.config_recorder_role_arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = var.config_resource_types
  }
}

resource "aws_config_delivery_channel" "platform" {
  name           = "${var.resource_prefix}-delivery"
  s3_bucket_name = var.config_bucket_id
  s3_key_prefix  = local.config_prefix

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.platform]
}

resource "aws_config_configuration_recorder_status" "platform" {
  name       = aws_config_configuration_recorder.platform.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.platform]
}

resource "aws_securityhub_account" "platform" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

# Only the Foundational Security Best Practices standard is enabled. Adding CIS
# as well would roughly double the per-check charge for overlapping findings.
resource "aws_securityhub_standards_subscription" "foundational" {
  count = var.enable_security_hub ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.platform]
}

# Flow logs go to S3 rather than CloudWatch Logs: S3 storage is far cheaper than
# per-GB log ingestion, and a no-NAT VPC produces very little traffic anyway.
resource "aws_flow_log" "analytics" {
  log_destination          = "${var.flow_log_bucket_arn}/vpc/"
  log_destination_type     = "s3"
  traffic_type             = var.flow_log_traffic_type
  vpc_id                   = var.vpc_id
  max_aggregation_interval = 600
  tags                     = merge(var.tags, { Purpose = "network-audit" })
}
