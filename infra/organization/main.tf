module "identity_center_access" {
  source = "../modules/identity_center_access"

  organization_admin_user_ids = [
    "c1bba500-a0e1-70e7-52c2-5101377f116d",
  ]
}

output "permission_set_arns" {
  description = "Identity Center permission sets managed by this root."
  value       = module.identity_center_access.permission_set_arns
}
