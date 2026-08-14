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

  assert {
    condition = (
      output.analytics.athena_workgroup_name == "data-platform-production-analytics" &&
      output.analytics.athena_query_cutoff_bytes == 10737418240 &&
      output.analytics.redshift_namespace_name == "data-platform-production-warehouse" &&
      output.analytics.redshift_workgroup_name == "data-platform-production-analytics" &&
      output.analytics.redshift_private &&
      output.analytics.redshift_base_capacity == 4 &&
      output.analytics.redshift_max_capacity == 4 &&
      output.analytics.redshift_monthly_rpu_hours == 16
    )
    error_message = "Production analytics must retain the low-cost Athena and private Redshift guardrails."
  }
}

# The account is supplied by committed tfvars rather than pinned in code so the
# platform can be deployed into another organization. The provider's
# allowed_account_ids still refuses credentials for a different account.
run "reject_malformed_account_id" {
  command = plan

  variables {
    aws_account_id = "not-an-account"
  }

  expect_failures = [var.aws_account_id]
}

run "reject_malformed_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.60.0.0/24"
  }

  expect_failures = [var.vpc_cidr]
}

run "reject_wrong_region" {
  command = plan

  variables {
    aws_region = "us-east-1"
  }

  expect_failures = [var.aws_region]
}
