output "arn" {
  description = "ARN of the bucket."
  value       = "arn:aws:s3:::${var.bucket_name}"
}

output "id" {
  description = "Name of the bucket."
  value       = var.bucket_name
}
