mock_provider "aws" {}

variables {
  aws_account_id = "991278600180"
}

run "production_environment_contract" {
  command = plan

  assert {
    condition     = output.aws_account_id == "991278600180"
    error_message = "Production must target the approved AWS account."
  }

  assert {
    condition     = output.environment == "production"
    error_message = "Production must retain its environment identity."
  }

  assert {
    condition     = output.resource_prefix == "data-platform-production"
    error_message = "Production resources must use an environment-qualified prefix."
  }

  assert {
    condition     = output.secret_namespace == "data-platform/production"
    error_message = "Production secrets must use an environment-qualified namespace."
  }

  assert {
    condition     = output.vpc_cidr == "10.60.0.0/16"
    error_message = "Production must retain its dedicated VPC CIDR."
  }
}

run "reject_invalid_account_id" {
  command = plan

  variables {
    aws_account_id = "511492912574"
  }

  expect_failures = [var.aws_account_id]
}

run "reject_wrong_region" {
  command = plan

  variables {
    aws_region = "us-east-1"
  }

  expect_failures = [var.aws_region]
}
