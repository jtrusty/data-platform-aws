mock_provider "aws" {}

variables {
  aws_account_id = "511492912574"
}

run "development_environment_contract" {
  command = plan

  assert {
    condition     = output.aws_account_id == "511492912574"
    error_message = "Development must target the approved AWS account."
  }

  assert {
    condition     = output.environment == "development"
    error_message = "Development must retain its environment identity."
  }

  assert {
    condition     = output.resource_prefix == "data-platform-development"
    error_message = "Development resources must use an environment-qualified prefix."
  }

  assert {
    condition     = output.secret_namespace == "data-platform/development"
    error_message = "Development secrets must use an environment-qualified namespace."
  }

  assert {
    condition     = output.vpc_cidr == "10.50.0.0/16"
    error_message = "Development must retain its dedicated VPC CIDR."
  }

  assert {
    condition = (
      output.analytics.athena_workgroup_name == "data-platform-development-analytics" &&
      output.analytics.athena_query_cutoff_bytes == 10737418240 &&
      output.analytics.redshift_namespace_name == "data-platform-development-warehouse" &&
      output.analytics.redshift_workgroup_name == "data-platform-development-analytics" &&
      output.analytics.redshift_private &&
      output.analytics.redshift_base_capacity == 4 &&
      output.analytics.redshift_max_capacity == 4 &&
      output.analytics.redshift_monthly_rpu_hours == 16
    )
    error_message = "Development analytics must retain the low-cost Athena and private Redshift guardrails."
  }
}

run "reject_invalid_account_id" {
  command = plan

  variables {
    aws_account_id = "555044956444"
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
