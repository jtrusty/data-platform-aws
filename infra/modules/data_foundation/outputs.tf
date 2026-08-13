output "bucket_names" {
  description = "Platform bucket names keyed by storage purpose."
  value       = { for purpose, bucket in module.platform_bucket : purpose => bucket.id }
}

output "bucket_arns" {
  description = "Platform bucket ARNs keyed by storage purpose."
  value       = { for purpose, bucket in module.platform_bucket : purpose => bucket.arn }
}

output "queue_urls" {
  description = "Work queue URLs keyed by workflow boundary."
  value       = { for name, queue in aws_sqs_queue.work : name => queue.id }
}

output "queue_arns" {
  description = "Work queue ARNs keyed by workflow boundary."
  value       = local.queue_arns
}

output "dead_letter_queue_urls" {
  description = "Dead-letter queue URLs keyed by workflow boundary."
  value       = { for name, queue in aws_sqs_queue.dead_letter : name => queue.id }
}

output "dead_letter_queue_arns" {
  description = "Dead-letter queue ARNs keyed by workflow boundary."
  value       = local.dead_letter_queue_arns
}

output "metadata_table_name" {
  description = "Platform metadata and watermark table name."
  value       = aws_dynamodb_table.metadata.name
}

output "metadata_table_arn" {
  description = "Platform metadata and watermark table ARN."
  value       = aws_dynamodb_table.metadata.arn
}

output "secret_arns" {
  description = "Opt-in secret container ARNs keyed by their namespace-relative names."
  value       = { for name, secret in aws_secretsmanager_secret.platform : name => secret.arn }
}

output "runtime_role_arns" {
  description = "Runtime role ARNs keyed by responsibility."
  value       = { for name, role in aws_iam_role.runtime : name => role.arn }
}
