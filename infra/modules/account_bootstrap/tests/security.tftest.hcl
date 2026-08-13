mock_provider "aws" {}

override_module {
  target          = module.state_backend
  override_during = plan
  outputs = {
    bucket_arn  = "arn:aws:s3:::jtrusty-dp-tfstate-sandbox-555044956444-us-east-2"
    bucket_name = "jtrusty-dp-tfstate-sandbox-555044956444-us-east-2"
    kms_key_arn = "arn:aws:kms:us-east-2:555044956444:key/00000000-0000-0000-0000-000000000000"
  }
}

variables {
  account_id              = "555044956444"
  environment             = "sandbox"
  github_environment      = "sandbox"
  github_owner_id         = "6896625"
  github_repository_id    = "1333254672"
  github_repository_name  = "data-platform-aws"
  github_repository_owner = "jtrusty"
  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "exact_github_trust" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "Only GitHub's official OIDC issuer may be trusted."
  }

  assert {
    condition     = toset(aws_iam_openid_connect_provider.github.client_id_list) == toset(["sts.amazonaws.com"])
    error_message = "The OIDC audience must be AWS STS only."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.terraform_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com" &&
      jsondecode(aws_iam_role.terraform_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:jtrusty@6896625/data-platform-aws@1333254672:environment:sandbox"
    )
    error_message = "OIDC trust must use exact immutable repository and environment claims."
  }

  assert {
    condition     = aws_iam_role.terraform_deploy.permissions_boundary == "arn:aws:iam::555044956444:policy/bootstrap/jtrusty-data-platform-deployment-boundary-sandbox"
    error_message = "The deployment role must use the bootstrap-owned boundary."
  }

  assert {
    condition     = !strcontains(local.terraform_deployment_policy, "iam:*")
    error_message = "The deployment boundary must not permit wildcard IAM administration."
  }

  assert {
    condition = alltrue([
      !contains(jsondecode(local.terraform_deployment_policy).Statement[0].Action, "s3:*"),
      !contains(jsondecode(local.terraform_deployment_policy).Statement[0].Action, "secretsmanager:*"),
      strcontains(local.terraform_deployment_policy, "arn:aws:s3:::data-platform-sandbox-*"),
      strcontains(local.terraform_deployment_policy, "secret:data-platform/sandbox/*"),
    ])
    error_message = "Platform S3 and secrets access must be namespace-scoped and must not include protected state."
  }

  assert {
    condition     = strcontains(local.terraform_deployment_policy, "iam:PassedToService")
    error_message = "PassRole must be conditioned on the target AWS service."
  }

  assert {
    condition = !contains(
      one([for statement in jsondecode(local.terraform_deployment_policy).Statement : statement if statement.Sid == "ManageRuntimeRoles"]).Action,
      "iam:PutRolePermissionsBoundary",
    )
    error_message = "The deployment role must not replace a runtime role's bootstrap-owned permissions boundary."
  }

  assert {
    condition = alltrue([
      strcontains(aws_iam_policy.runtime_boundary.policy, "DenyTerraformStateData"),
      strcontains(aws_iam_policy.runtime_boundary.policy, "DenyTerraformStateKey"),
      strcontains(aws_iam_policy.runtime_boundary.policy, "jtrusty-dp-tfstate-sandbox"),
      strcontains(aws_iam_policy.runtime_boundary.policy, "arn:aws:s3:::data-platform-sandbox-*"),
      strcontains(aws_iam_policy.runtime_boundary.policy, "secret:data-platform/sandbox/*"),
      strcontains(aws_iam_policy.runtime_boundary.policy, "dynamodb:us-east-2:555044956444:table/data-platform-sandbox-*"),
      strcontains(aws_iam_policy.runtime_boundary.policy, "sqs:us-east-2:555044956444:data-platform-sandbox-*"),
    ])
    error_message = "The runtime boundary must scope platform data and explicitly deny all state data and state KMS access."
  }

  assert {
    condition = (
      length(replace(aws_iam_policy.runtime_boundary.policy, " ", "")) <= 6144 &&
      length(replace(local.terraform_deployment_policy, " ", "")) <= 6144
    )
    error_message = "Managed permissions-boundary policies must fit the 6,144-character IAM quota."
  }

  assert {
    condition     = !strcontains(local.terraform_deployment_policy, "arn:aws:iam::699599381258")
    error_message = "Workload CI must have no management-account trust or resources."
  }
}

run "reject_wrong_repository" {
  command = plan

  variables {
    github_repository_name = "other-repository"
  }

  expect_failures = [var.github_repository_name]
}
