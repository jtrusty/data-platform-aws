mock_provider "aws" {}

variables {
  aws_account_id           = "555044956444"
  environment              = "sandbox"
  resource_prefix          = "data-platform-sandbox"
  athena_results_bucket_id = "data-platform-sandbox-athena-results-555044956444"
  bronze_bucket_id         = "data-platform-sandbox-bronze-555044956444"
  silver_bucket_id         = "data-platform-sandbox-silver-555044956444"

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "creates_cost_controlled_athena" {
  command = apply

  assert {
    condition     = aws_athena_workgroup.analytics.name == "data-platform-sandbox-analytics"
    error_message = "Athena must use the environment-qualified analytics workgroup."
  }

  assert {
    condition = (
      one(aws_athena_workgroup.analytics.configuration).enforce_workgroup_configuration &&
      one(aws_athena_workgroup.analytics.configuration).publish_cloudwatch_metrics_enabled &&
      one(aws_athena_workgroup.analytics.configuration).bytes_scanned_cutoff_per_query == 10737418240
    )
    error_message = "Athena must enforce workgroup settings, publish metrics, and default to a 10 GiB per-query scan cap."
  }

  assert {
    condition = (
      one(one(aws_athena_workgroup.analytics.configuration).result_configuration).output_location == "s3://data-platform-sandbox-athena-results-555044956444/analytics/" &&
      one(one(aws_athena_workgroup.analytics.configuration).result_configuration).expected_bucket_owner == "555044956444" &&
      one(one(one(aws_athena_workgroup.analytics.configuration).result_configuration).encryption_configuration).encryption_option == "SSE_S3"
    )
    error_message = "Athena results must use the exact account-owned encrypted results prefix."
  }

  assert {
    condition     = one(aws_athena_workgroup.analytics.configuration).engine_version[0].selected_engine_version == "Athena engine version 3"
    error_message = "Athena must pin the current engine generation instead of silently selecting an older engine."
  }

  assert {
    condition     = toset(keys(aws_glue_catalog_database.layer)) == toset(["bronze", "silver"])
    error_message = "The baseline catalog must contain only Bronze and Silver lake databases."
  }

  assert {
    condition = (
      aws_glue_catalog_database.layer["bronze"].name == "data_platform_sandbox_bronze" &&
      aws_glue_catalog_database.layer["bronze"].location_uri == "s3://data-platform-sandbox-bronze-555044956444/" &&
      aws_glue_catalog_database.layer["silver"].name == "data_platform_sandbox_silver" &&
      aws_glue_catalog_database.layer["silver"].location_uri == "s3://data-platform-sandbox-silver-555044956444/"
    )
    error_message = "Catalog databases must map to the exact environment lake buckets."
  }
}

run "rejects_tiny_scan_limit" {
  command = plan

  variables {
    bytes_scanned_cutoff_per_query = 1048575
  }

  expect_failures = [var.bytes_scanned_cutoff_per_query]
}

run "rejects_cross_account_results_bucket" {
  command = plan

  variables {
    athena_results_bucket_id = "data-platform-sandbox-athena-results-991278600180"
  }

  expect_failures = [var.athena_results_bucket_id]
}
