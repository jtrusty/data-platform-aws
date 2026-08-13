mock_provider "aws" {}

variables {
  instance_arn                = "arn:aws:sso:::instance/ssoins-6684759f0418edd4"
  identity_store_id           = "d-9a675d55f3"
  organization_admin_user_ids = ["11111111-2222-3333-4444-555555555555"]
  platform_admins_group_id    = "118b3590-f061-7088-bff1-cc1c9f78d5c3"
  data_engineers_group_id     = "619b5560-5001-707a-8057-b239ffbd3ae1"
}

run "group_assignment_matrix" {
  command = plan

  assert {
    condition     = length(aws_ssoadmin_account_assignment.organization_admin) == 1
    error_message = "Exactly one named organization administrator must receive management-account access in this test."
  }

  assert {
    condition     = length(aws_ssoadmin_account_assignment.platform_admin) == 3
    error_message = "PlatformAdmins must be assigned only to the three workload accounts."
  }

  assert {
    condition     = length(aws_ssoadmin_account_assignment.data_engineer_nonprod) == 2 && length(aws_ssoadmin_account_assignment.data_engineer_production) == 1
    error_message = "DataEngineers need separate non-production and production assignments."
  }

  assert {
    condition     = aws_ssoadmin_permission_set.data_engineer_nonprod.session_duration == "PT4H" && aws_ssoadmin_permission_set.data_engineer_production.session_duration == "PT2H"
    error_message = "Production engineer sessions must be shorter than non-production sessions."
  }

  assert {
    condition = alltrue(concat(
      [for assignment in aws_ssoadmin_account_assignment.platform_admin : assignment.principal_type == "GROUP"],
      [for assignment in aws_ssoadmin_account_assignment.data_engineer_nonprod : assignment.principal_type == "GROUP"],
      [for assignment in aws_ssoadmin_account_assignment.data_engineer_production : assignment.principal_type == "GROUP"],
    ))
    error_message = "Workload account access must be assigned through groups."
  }

  assert {
    condition     = alltrue([for assignment in aws_ssoadmin_account_assignment.organization_admin : assignment.principal_type == "USER" && assignment.target_id == "699599381258"])
    error_message = "Management-account administration must be assigned directly to named users."
  }
}

run "data_engineer_has_no_admin_escape" {
  command = plan

  assert {
    condition = alltrue([
      !strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "AdministratorAccess"),
      !strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "PowerUserAccess"),
      !strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "iam:*"),
      !strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "organizations:*"),
    ])
    error_message = "DataEngineer must not receive admin, wildcard IAM, Organizations, or state access."
  }

  assert {
    condition = alltrue(flatten([
      for policy in [
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy),
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy),
        ] : [
        for statement in policy.Statement : alltrue([
          for resource in try(tolist(statement.Resource), [statement.Resource]) :
          statement.Effect != "Allow" || !strcontains(resource, "jtrusty-dp-tfstate")
        ])
      ]
    ]))
    error_message = "No DataEngineer allow statement may reference Terraform state resources."
  }

  assert {
    condition = (
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "iam:PassRole") &&
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "iam:PassedToService")
    )
    error_message = "DataEngineer PassRole must be service-conditioned."
  }

  assert {
    condition = alltrue(flatten([
      for policy in [
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy),
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy),
        ] : [
        for statement in policy.Statement :
        !contains(try(tolist(statement.Action), [statement.Action]), "iam:PassRole") || (
          can(statement.Condition.StringEquals["iam:PassedToService"]) &&
          alltrue([for resource in try(tolist(statement.Resource), [statement.Resource]) : startswith(resource, "arn:aws:iam::") && strcontains(resource, ":role/data-platform/runtime/data-platform-")])
        )
      ]
    ]))
    error_message = "Every PassRole statement must use exact runtime role ARNs and iam:PassedToService."
  }

  assert {
    condition = alltrue([
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "lambda:us-east-2:555044956444:function:data-platform-sandbox-*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "dynamodb:us-east-2:511492912574:table/data-platform-development-*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy, "sqs:us-east-2:991278600180:data-platform-production-*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy, "kms:Decrypt"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy, "DenyProductionStateKey"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "dynamodb:CreateTable"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "sqs:CreateQueue"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "athena:*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "states:*"),
    ])
    error_message = "DataEngineer must have platform-scoped resources, data-key use, state-key denial, and normal resource lifecycle actions."
  }

  assert {
    condition = (
      length(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy) <= 10240 &&
      length(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy) <= 10240
    )
    error_message = "Identity Center inline policies must fit the 10,240-byte non-whitespace permission-set quota."
  }
}
