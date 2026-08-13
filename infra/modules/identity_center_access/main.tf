locals {
  management_account_id = "699599381258"
  workload_accounts = {
    sandbox     = "555044956444"
    development = "511492912574"
    production  = "991278600180"
  }
  nonprod_accounts = {
    sandbox     = local.workload_accounts.sandbox
    development = local.workload_accounts.development
  }
}

resource "aws_ssoadmin_permission_set" "organization_admin" {
  name             = "OrganizationAdmin"
  description      = "Exceptional administration of AWS Organizations and Identity Center"
  instance_arn     = var.instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_permission_set" "platform_admin" {
  name             = "PlatformAdmin"
  description      = "Exceptional administration of data-platform workload accounts"
  instance_arn     = var.instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_permission_set" "data_engineer_nonprod" {
  name             = "DataEngineerNonProd"
  description      = "Broad operation of sandbox and development data-platform resources"
  instance_arn     = var.instance_arn
  session_duration = "PT4H"
}

resource "aws_ssoadmin_permission_set" "data_engineer_production" {
  name             = "DataEngineerProduction"
  description      = "Production data-platform operation and troubleshooting"
  instance_arn     = var.instance_arn
  session_duration = "PT2H"
}

resource "aws_ssoadmin_managed_policy_attachment" "organization_admin" {
  instance_arn       = var.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.organization_admin.arn
}

resource "aws_ssoadmin_managed_policy_attachment" "platform_admin" {
  instance_arn       = var.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "data_engineer_nonprod" {
  inline_policy      = local.data_engineer_nonprod_policy
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_nonprod.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "data_engineer_production" {
  inline_policy      = local.data_engineer_production_policy
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_production.arn
}

resource "aws_ssoadmin_account_assignment" "organization_admin" {
  for_each = var.organization_admin_user_ids

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.organization_admin.arn
  principal_id       = each.value
  principal_type     = "USER"
  target_id          = local.management_account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admin" {
  for_each = local.workload_accounts

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  principal_id       = var.platform_admins_group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "data_engineer_nonprod" {
  for_each = local.nonprod_accounts

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_nonprod.arn
  principal_id       = var.data_engineers_group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "data_engineer_production" {
  for_each = { production = local.workload_accounts.production }

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_production.arn
  principal_id       = var.data_engineers_group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}
