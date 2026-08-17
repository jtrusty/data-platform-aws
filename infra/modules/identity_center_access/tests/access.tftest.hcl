mock_provider "aws" {
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-0000000000000000"]
      identity_store_ids = ["d-0000000000"]
    }
  }
}

variables {
  instance_arn                = "arn:aws:sso:::instance/ssoins-6684759f0418edd4"
  identity_store_id           = "d-9a675d55f3"
  organization_admin_user_ids = ["11111111-2222-3333-4444-555555555555"]
  platform_admins_group_id    = "118b3590-f061-7088-bff1-cc1c9f78d5c3"
  data_engineers_group_id     = "619b5560-5001-707a-8057-b239ffbd3ae1"
  management_account_id       = "699599381258"
  workload_accounts = {
    sandbox     = "555044956444"
    development = "511492912574"
    production  = "991278600180"
  }
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
    condition = (
      aws_ssoadmin_customer_managed_policy_attachment.query_editor_nonprod.customer_managed_policy_reference[0].name == "jtrusty-data-platform-query-editor-v2" &&
      aws_ssoadmin_customer_managed_policy_attachment.query_editor_nonprod.customer_managed_policy_reference[0].path == "/data-platform/human/" &&
      aws_ssoadmin_customer_managed_policy_attachment.query_editor_production.customer_managed_policy_reference[0].name == "jtrusty-data-platform-query-editor-v2" &&
      aws_ssoadmin_customer_managed_policy_attachment.query_editor_production.customer_managed_policy_reference[0].path == "/data-platform/human/"
    )
    error_message = "Both DataEngineer permission sets must attach the workload-account Query Editor policy."
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
      !strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "redshift-data:List*"),
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
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "dynamodb:*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "sqs:*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "athena:*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "athena:us-east-2:555044956444:datacatalog/AwsDataCatalog"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "states:*"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "log-group:/aws/redshift/data-platform-sandbox-warehouse/*"),
    ])
    error_message = "DataEngineer must have platform-scoped resources, data-key use, state-key denial, and normal resource lifecycle actions."
  }

  assert {
    condition = alltrue([
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "ProtectDurabilityAndRetention"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "ProtectCostControls"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "ProtectAgainstDataMovement"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "ProtectResourcePoliciesAndPublicAccess"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy, "ProtectResourcePoliciesAndPublicAccess"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy, "ProtectDevelopmentBaselineQueues"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy, "ProtectProductionBaselineQueues"),
      strcontains(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy, "ProtectProductionMetadata"),
    ])
    error_message = "DataEngineer must be able to replay DLQs without being able to purge or delete Terraform baseline queues and metadata."
  }

  assert {
    condition = alltrue([
      for policy in [
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy),
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy),
        ] : (
        anytrue([
          for statement in policy.Statement :
          contains(try(tolist(statement.Action), [statement.Action]), "redshift-data:ExecuteStatement") &&
          alltrue([for resource in try(tolist(statement.Resource), [statement.Resource]) :
            endswith(resource, ":workgroup/*") || endswith(resource, ":namespace/*")
          ]) &&
          can(statement.Condition.StringEquals["aws:ResourceTag/Platform"])
        ]) &&
        anytrue([
          for statement in policy.Statement :
          contains(try(tolist(statement.Action), [statement.Action]), "redshift-data:GetStatementResult") &&
          statement.Resource == "*" &&
          statement.Condition.StringEquals["redshift-data:statement-owner-iam-userid"] == "$${aws:userid}"
        ])
      )
    ])
    error_message = "DataEngineer Data API access must target tagged Serverless IDs and restrict statement results to the caller."
  }

  assert {
    condition = (
      length(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy) <= 10240 &&
      length(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy) <= 10240
    )
    error_message = "Identity Center inline policies must fit the 10,240-byte non-whitespace permission-set quota."
  }
}

# glue:* is scoped to the platform's own Glue resources, so the catalog-wide
# security settings must be denied outright.
run "security_boundary_stays_with_terraform" {
  command = plan

  assert {
    condition = alltrue([
      for policy in [
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy),
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy),
        ] : anytrue([
          for statement in policy.Statement :
          statement.Sid == "ProtectResourcePoliciesAndPublicAccess" &&
          statement.Effect == "Deny" &&
          contains(statement.Action, "glue:PutResourcePolicy") &&
          contains(statement.Action, "glue:PutDataCatalogEncryptionSettings")
      ])
    ])
    error_message = "Resource policies and public-access controls decide who can reach platform data and must stay Terraform-owned."
  }
}

# Terraform owns bucket creation and the cost caps. An engineer-made Athena
# workgroup would carry no per-query scan cutoff and would be invisible to the
# monthly spend guard.
# Platform tags are what several conditions in this policy match on, so the
# ability to set them is the ability to grant access.
run "engineers_cannot_retag_resources" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for policy in [
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy),
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy),
        ] : [
        for statement in policy.Statement :
        statement.Effect != "Allow" || !anytrue([
          for action in try(tolist(statement.Action), [statement.Action]) :
          action == "ec2:CreateTags" || action == "ec2:DeleteTags" || action == "ec2:*"
        ])
      ]
    ]))
    error_message = "Tagging EC2 resources would let an engineer satisfy the platform tag conditions this policy relies on."
  }
}

run "cost_and_creation_controls_stay_with_terraform" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for policy in [
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod.inline_policy),
        jsondecode(aws_ssoadmin_permission_set_inline_policy.data_engineer_production.inline_policy),
        ] : [
        for denied in ["athena:CreateWorkGroup", "s3:CreateBucket", "s3:DeleteObjectVersion", "logs:PutSubscriptionFilter", "dynamodb:CreateTableReplica"] :
        anytrue([
          for statement in policy.Statement :
          statement.Effect == "Deny" && contains(try(tolist(statement.Action), [statement.Action]), denied)
        ])
      ]
    ]))
    error_message = "Bucket creation, version deletion, cross-account log delivery, table replicas, and uncapped Athena workgroups must all stay denied."
  }
}
