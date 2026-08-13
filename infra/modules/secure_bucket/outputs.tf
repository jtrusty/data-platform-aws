output "arn" {
  description = "ARN of the bucket."
  value       = aws_s3_bucket.this.arn
}

output "id" {
  description = "Name of the bucket."
  value       = aws_s3_bucket.this.id
}
