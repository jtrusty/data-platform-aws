output "alert_topic_arn" {
  description = "SNS topic receiving budget notifications and platform alarms."
  value       = aws_sns_topic.alerts.arn
}

output "alert_email_subscribed" {
  description = "Whether an email subscription was created for platform alerts. Only the fact is published, never the address."
  value       = nonsensitive(var.alert_email != null)
}

output "budget_name" {
  description = "Monthly account cost budget name."
  value       = aws_budgets_budget.account.name
}

output "monthly_budget_usd" {
  description = "Monthly account cost budget in USD."
  value       = var.monthly_budget_usd
}

output "athena_monthly_bytes_limit" {
  description = "Month-to-date Athena scanned bytes that disable the workgroup."
  value       = var.athena_monthly_bytes_limit
}

output "athena_spend_guard_function_name" {
  description = "Lambda function that enforces the Athena monthly limit."
  value       = aws_lambda_function.athena_spend_guard.function_name
}

output "alarm_names" {
  description = "CloudWatch alarms publishing to the platform alert topic."
  value       = concat([aws_cloudwatch_metric_alarm.athena_scanned_bytes.alarm_name], [for alarm in aws_cloudwatch_metric_alarm.dead_letter_queue : alarm.alarm_name])
}
