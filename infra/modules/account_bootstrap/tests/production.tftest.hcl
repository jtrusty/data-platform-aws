mock_provider "aws" {}

override_module {
  target          = module.state_backend
  override_during = plan
  outputs = {
    bucket_arn  = "arn:aws:s3:::jtrusty-data-platform-tfstate-production-991278600180-us-east-2"
    bucket_name = "jtrusty-data-platform-tfstate-production-991278600180-us-east-2"
    kms_key_arn = "arn:aws:kms:us-east-2:991278600180:key/00000000-0000-0000-0000-000000000000"
  }
}

variables {
  account_id              = "991278600180"
  environment             = "production"
  github_environment      = "production"
  github_owner_id         = "6896625"
  github_repository_id    = "1333254672"
  github_repository_name  = "data-platform-aws"
  github_repository_owner = "jtrusty"
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "production_plan_role_is_read_only" {
  command = plan

  assert {
    condition = (
      jsondecode(aws_iam_role.terraform_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:jtrusty@6896625/data-platform-aws@1333254672:environment:production" &&
      jsondecode(aws_iam_role.terraform_plan[0].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:jtrusty@6896625/data-platform-aws@1333254672:environment:production-plan"
    )
    error_message = "Production apply and plan roles must trust separate exact GitHub Environments."
  }

  assert {
    condition = alltrue([
      strcontains(aws_iam_role_policy.terraform_plan[0].policy, "terraform.tfstate.tflock"),
      strcontains(aws_iam_role_policy.terraform_plan[0].policy, "kms:GenerateDataKey"),
      strcontains(aws_iam_role_policy.terraform_plan[0].policy, "data-platform-production-*"),
      !strcontains(aws_iam_role_policy.terraform_plan[0].policy, "jtrusty-data-platform-terraform-deploy"),
      !strcontains(aws_iam_role_policy.terraform_plan[0].policy, "iam:PassRole"),
      !strcontains(aws_iam_role_policy.terraform_plan[0].policy, "s3:PutBucket"),
      !strcontains(aws_iam_role_policy.terraform_plan[0].policy, "arn:aws:s3:::data-platform-production-*/*"),
      !strcontains(aws_iam_role_policy.terraform_plan[0].policy, "lambda:Update"),
      strcontains(aws_iam_role_policy.terraform_plan[0].policy, "lambda:us-east-2:991278600180:function:data-platform-production-*"),
      !contains(one([for statement in jsondecode(aws_iam_role_policy.terraform_plan[0].policy).Statement : statement if statement.Sid == "ReadPlatform"]).Action, "lambda:Get*"),
      !contains(one([for statement in jsondecode(aws_iam_role_policy.terraform_plan[0].policy).Statement : statement if statement.Sid == "ReadPlatform"]).Action, "logs:Get*"),
    ])
    error_message = "The production plan role may lock/read state and inspect only; it must not mutate infrastructure."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_role_policy.terraform_plan[0].policy).Statement :
      !contains(try(tolist(statement.Action), [statement.Action]), "s3:GetObject") || (
        contains(["ReadState", "LockState"], statement.Sid) &&
        alltrue([
          for resource in statement.Resource : contains([
            "arn:aws:s3:::jtrusty-data-platform-tfstate-production-991278600180-us-east-2/data-platform/production/terraform.tfstate",
            "arn:aws:s3:::jtrusty-data-platform-tfstate-production-991278600180-us-east-2/data-platform/production/terraform.tfstate.tflock",
          ], resource)
        ])
      )
    ])
    error_message = "Production plan GetObject access must be limited to the exact Terraform state and lock objects."
  }
}
