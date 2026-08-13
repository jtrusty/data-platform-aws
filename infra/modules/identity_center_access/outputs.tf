output "identity_store_id" {
  description = "Confirmed Identity Center identity store ID."
  value       = var.identity_store_id
}

output "permission_set_arns" {
  description = "Managed Identity Center permission set ARNs."
  value = {
    organization_admin       = aws_ssoadmin_permission_set.organization_admin.arn
    platform_admin           = aws_ssoadmin_permission_set.platform_admin.arn
    data_engineer_nonprod    = aws_ssoadmin_permission_set.data_engineer_nonprod.arn
    data_engineer_production = aws_ssoadmin_permission_set.data_engineer_production.arn
  }
}
