output "identity_store_id" {
  description = "Confirmed Identity Center identity store ID."
  value       = local.identity_store_id
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

output "instance_arn" {
  description = "Identity Center instance the permission sets belong to."
  value       = local.instance_arn
}

output "group_ids" {
  description = "Group IDs assigned to the managed permission sets."
  value = {
    data_engineers  = local.data_engineers_group_id
    platform_admins = local.platform_admins_group_id
  }
}
