output "deployment_role_arn" {
  description = "GitHub OIDC platform deployment role ARN."
  value       = aws_iam_role.terraform_deploy.arn
}

output "plan_role_arn" {
  description = "Production read-only Terraform plan role ARN, if applicable."
  value       = try(aws_iam_role.terraform_plan[0].arn, null)
}

output "runtime_boundary_arn" {
  description = "Bootstrap-owned runtime permissions boundary ARN."
  value       = aws_iam_policy.runtime_boundary.arn
}

output "state_bucket_name" {
  description = "Environment Terraform state bucket name."
  value       = module.state_backend.bucket_name
}

output "state_kms_key_arn" {
  description = "Environment Terraform state KMS key ARN."
  value       = module.state_backend.kms_key_arn
}
