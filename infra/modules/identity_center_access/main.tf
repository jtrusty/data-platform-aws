# The organization instance must already be enabled; AWS provides no API to
# create one. It is discovered rather than pinned so this module can be used in
# an organization that already has Identity Center.
data "aws_ssoadmin_instances" "organization" {}

resource "aws_identitystore_group" "platform_admins" {
  count = var.create_groups ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = var.platform_admins_group_name
  description       = "Exceptional administration of data-platform workload accounts"
}

resource "aws_identitystore_group" "data_engineers" {
  count = var.create_groups ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = var.data_engineers_group_name
  description       = "Data platform engineers"
}

locals {
  instance_arn      = coalesce(var.instance_arn, one(data.aws_ssoadmin_instances.organization.arns))
  identity_store_id = coalesce(var.identity_store_id, one(data.aws_ssoadmin_instances.organization.identity_store_ids))

  platform_admins_group_id = var.create_groups ? one(aws_identitystore_group.platform_admins).group_id : var.platform_admins_group_id
  data_engineers_group_id  = var.create_groups ? one(aws_identitystore_group.data_engineers).group_id : var.data_engineers_group_id

  management_account_id = var.management_account_id
  workload_accounts     = var.workload_accounts
  nonprod_accounts = {
    for name, account_id in var.workload_accounts : name => account_id
    if name != "production"
  }
}

resource "aws_ssoadmin_permission_set" "organization_admin" {
  name             = "${var.permission_set_prefix}OrganizationAdmin"
  description      = "Exceptional administration of AWS Organizations and Identity Center"
  instance_arn     = local.instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_permission_set" "platform_admin" {
  name             = "${var.permission_set_prefix}PlatformAdmin"
  description      = "Exceptional administration of data-platform workload accounts"
  instance_arn     = local.instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_permission_set" "data_engineer_nonprod" {
  name             = "${var.permission_set_prefix}DataEngineerNonProd"
  description      = "Broad operation of sandbox and development data-platform resources"
  instance_arn     = local.instance_arn
  session_duration = "PT4H"
}

resource "aws_ssoadmin_permission_set" "data_engineer_production" {
  name             = "${var.permission_set_prefix}DataEngineerProduction"
  description      = "Production data-platform operation and troubleshooting"
  instance_arn     = local.instance_arn
  session_duration = "PT2H"
}

resource "aws_ssoadmin_managed_policy_attachment" "organization_admin" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.organization_admin.arn
}

resource "aws_ssoadmin_managed_policy_attachment" "platform_admin" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "data_engineer_nonprod" {
  inline_policy      = local.data_engineer_nonprod_policy
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_nonprod.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "data_engineer_production" {
  inline_policy      = local.data_engineer_production_policy
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_production.arn
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "query_editor_nonprod" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_nonprod.arn

  customer_managed_policy_reference {
    name = "${var.human_policy_prefix}-query-editor-v2"
    path = "/data-platform/human/"
  }
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "query_editor_production" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_production.arn

  customer_managed_policy_reference {
    name = "${var.human_policy_prefix}-query-editor-v2"
    path = "/data-platform/human/"
  }
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "region_guardrail_nonprod" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_nonprod.arn

  customer_managed_policy_reference {
    name = "${var.human_policy_prefix}-region-guardrail"
    path = "/data-platform/human/"
  }
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "region_guardrail_production" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_production.arn

  customer_managed_policy_reference {
    name = "${var.human_policy_prefix}-region-guardrail"
    path = "/data-platform/human/"
  }
}

resource "aws_ssoadmin_account_assignment" "organization_admin" {
  for_each = var.organization_admin_user_ids

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.organization_admin.arn
  principal_id       = each.value
  principal_type     = "USER"
  target_id          = local.management_account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admin" {
  for_each = local.workload_accounts

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  principal_id       = local.platform_admins_group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "data_engineer_nonprod" {
  for_each = local.nonprod_accounts

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_nonprod.arn
  principal_id       = local.data_engineers_group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "data_engineer_production" {
  for_each = { production = local.workload_accounts.production }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer_production.arn
  principal_id       = local.data_engineers_group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}
