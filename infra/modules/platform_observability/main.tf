locals {
  topic_name    = "${var.resource_prefix}-alerts"
  topic_arn     = "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${local.topic_name}"
  function_name = "${var.resource_prefix}-athena-spend-guard"

  # CloudWatch cannot alarm on a calendar-month sum, so the alarm fires on a
  # daily allowance and the guard function makes the monthly decision.
  daily_bytes_allowance = ceil(var.athena_monthly_bytes_limit / 30)
}

# Alerts carry no sensitive data, and the AWS-managed SNS key has no monthly
# charge where a customer-managed key would add one per account.
#trivy:ignore:AVD-AWS-0136:exp:2027-08-13
resource "aws_sns_topic" "alerts" {
  name = local.topic_name
  # The AWS-managed SNS key has no monthly charge, unlike a customer-managed key.
  kms_master_key_id = "alias/aws/sns"
  tags              = merge(var.tags, { Purpose = "platform-alerts" })
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountOwnerAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }
        Action    = ["sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:Subscribe", "sns:Publish", "sns:ListSubscriptionsByTopic"]
        Resource  = local.topic_arn
      },
      {
        Sid       = "AllowPlatformServicePublishing"
        Effect    = "Allow"
        Principal = { Service = ["budgets.amazonaws.com", "cloudwatch.amazonaws.com"] }
        Action    = "sns:Publish"
        Resource  = local.topic_arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.aws_account_id }
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

# The address is supplied out of band and marked sensitive, so it never reaches
# this public repository or a plan printed into a public workflow log.
resource "aws_sns_topic_subscription" "alert_email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# AWS Budgets notifies; it does not stop spend. The Athena guard below is the
# control that actually halts the platform's most open-ended cost.
resource "aws_budgets_budget" "account" {
  name         = "${var.resource_prefix}-monthly"
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

data "archive_file" "athena_spend_guard" {
  type        = "zip"
  source_file = "${path.module}/functions/athena_spend_guard.py"
  output_path = "${path.module}/functions/athena_spend_guard.zip"
}

resource "aws_cloudwatch_log_group" "athena_spend_guard" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { Purpose = "athena-spend-guard" })
}

resource "aws_lambda_function" "athena_spend_guard" {
  function_name    = local.function_name
  role             = var.guard_role_arn
  runtime          = "python3.13"
  handler          = "athena_spend_guard.handler"
  filename         = data.archive_file.athena_spend_guard.output_path
  source_code_hash = data.archive_file.athena_spend_guard.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      ATHENA_WORKGROUP           = var.athena_workgroup_name
      ATHENA_MONTHLY_BYTES_LIMIT = tostring(var.athena_monthly_bytes_limit)
    }
  }

  tags = merge(var.tags, { Purpose = "athena-spend-guard" })

  depends_on = [aws_cloudwatch_log_group.athena_spend_guard]
}

resource "aws_sns_topic_subscription" "athena_spend_guard" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.athena_spend_guard.arn
}

resource "aws_lambda_permission" "athena_spend_guard" {
  statement_id   = "AllowPlatformAlertTopic"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.athena_spend_guard.function_name
  principal      = "sns.amazonaws.com"
  source_arn     = aws_sns_topic.alerts.arn
  source_account = var.aws_account_id
}

resource "aws_cloudwatch_metric_alarm" "athena_scanned_bytes" {
  alarm_name          = "${var.resource_prefix}-athena-scanned-bytes"
  alarm_description   = "Athena scanned more than one day's share of the monthly byte allowance; the spend guard re-checks the month-to-date total."
  namespace           = "AWS/Athena"
  metric_name         = "ProcessedBytes"
  dimensions          = { WorkGroup = var.athena_workgroup_name }
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = local.daily_bytes_allowance
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  tags                = merge(var.tags, { Purpose = "athena-spend-guard" })
}

resource "aws_cloudwatch_metric_alarm" "dead_letter_queue" {
  for_each = var.dead_letter_queue_names

  alarm_name          = "${each.value}-messages"
  alarm_description   = "Messages are waiting in the ${each.value} dead-letter queue."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = each.value }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = merge(var.tags, { Purpose = "dead-letter-monitoring" })
}
