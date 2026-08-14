# Account, instance, and group identifiers are configuration, not credentials.
management_account_id = "699599381258"

workload_accounts = {
  sandbox     = "555044956444"
  development = "511492912574"
  production  = "991278600180"
}

organization_admin_user_ids = ["c1bba500-a0e1-70e7-52c2-5101377f116d"]

identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-6684759f0418edd4"
identity_store_id            = "d-9a675d55f3"
platform_admins_group_id     = "118b3590-f061-7088-bff1-cc1c9f78d5c3"
data_engineers_group_id      = "619b5560-5001-707a-8057-b239ffbd3ae1"

# This organization exists for the data platform, so one organization trail is
# both cheaper and broader than per-account trails.
organization_trail = true
