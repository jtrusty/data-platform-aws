mock_provider "aws" {}
mock_provider "archive" {}

variables {
  aws_account_id             = "555044956444"
  environment                = "sandbox"
  resource_prefix            = "data-platform-sandbox"
  athena_workgroup_name      = "data-platform-sandbox-analytics"
  athena_monthly_bytes_limit = 107374182400
  guard_role_arn             = "arn:aws:iam::555044956444:role/data-platform/runtime/data-platform-sandbox-athena-guard"
  dead_letter_queue_names = [
    "data-platform-sandbox-ingest-dlq",
    "data-platform-sandbox-bronze-complete-dlq",
  ]
  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "budget_and_athena_limit_are_enforced" {
  command = plan

  assert {
    condition = (
      aws_budgets_budget.account.name == "data-platform-sandbox-monthly" &&
      aws_budgets_budget.account.limit_amount == "25" &&
      aws_budgets_budget.account.limit_unit == "USD" &&
      aws_budgets_budget.account.time_unit == "MONTHLY" &&
      aws_budgets_budget.account.budget_type == "COST"
    )
    error_message = "Each account must carry a monthly USD cost budget."
  }

  # CloudWatch cannot sum a calendar month, so the alarm must fire on a daily
  # share and the function makes the monthly decision.
  assert {
    condition = (
      aws_cloudwatch_metric_alarm.athena_scanned_bytes.threshold == ceil(107374182400 / 30) &&
      aws_cloudwatch_metric_alarm.athena_scanned_bytes.period == 86400 &&
      aws_cloudwatch_metric_alarm.athena_scanned_bytes.treat_missing_data == "notBreaching" &&
      aws_lambda_function.athena_spend_guard.environment[0].variables["ATHENA_MONTHLY_BYTES_LIMIT"] == "107374182400"
    )
    error_message = "The Athena guard must alarm on a daily allowance and enforce the real monthly byte limit."
  }

  assert {
    condition = (
      aws_lambda_function.athena_spend_guard.role == var.guard_role_arn &&
      aws_lambda_permission.athena_spend_guard.principal == "sns.amazonaws.com" &&
      aws_lambda_permission.athena_spend_guard.source_account == var.aws_account_id
    )
    error_message = "Only this account's alert topic may invoke the spend guard, using the bootstrap-owned role."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.dead_letter_queue) == 2
    error_message = "Every dead-letter queue must be alarmed."
  }

  assert {
    condition     = aws_sns_topic.alerts.kms_master_key_id == "alias/aws/sns"
    error_message = "Alert encryption must use the no-cost AWS-managed SNS key."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_sns_topic_policy.alerts.policy).Statement : statement if statement.Sid == "DenyInsecureTransport"]).Effect == "Deny" &&
      one([for statement in jsondecode(aws_sns_topic_policy.alerts.policy).Statement : statement if statement.Sid == "AllowPlatformServicePublishing"]).Condition.StringEquals["aws:SourceAccount"] == var.aws_account_id
    )
    error_message = "Only same-account budgets and alarms may publish, and never without TLS."
  }

  assert {
    condition     = length(aws_sns_topic_subscription.alert_email) == 0
    error_message = "No email subscription may be created when no address is supplied."
  }
}

run "supplied_address_is_subscribed" {
  command = plan

  variables {
    alert_email = "platform@example.com"
  }

  assert {
    condition     = length(aws_sns_topic_subscription.alert_email) == 1
    error_message = "A supplied alert address must be subscribed to the topic."
  }
}

run "reject_invalid_address" {
  command = plan

  variables {
    alert_email = "not-an-address"
  }

  expect_failures = [var.alert_email]
}

run "reject_foreign_guard_role" {
  command = plan

  variables {
    guard_role_arn = "arn:aws:iam::555044956444:role/data-platform/runtime/data-platform-sandbox-ingest"
  }

  expect_failures = [var.guard_role_arn]
}
