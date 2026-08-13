output "bucket_arn" {
  description = "Terraform state bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Terraform state bucket name."
  value       = aws_s3_bucket.this.id
}

output "kms_key_arn" {
  description = "Terraform state KMS key ARN."
  value       = aws_kms_key.this.arn
}
