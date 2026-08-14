locals {
  catalog_prefix = replace(var.resource_prefix, "-", "_")
  lake_buckets = {
    bronze = var.bronze_bucket_id
    silver = var.silver_bucket_id
  }
}

resource "aws_glue_catalog_database" "layer" {
  for_each = local.lake_buckets

  catalog_id   = var.aws_account_id
  name         = "${local.catalog_prefix}_${each.key}"
  description  = "${title(each.key)} data lake catalog for ${var.environment}"
  location_uri = "s3://${each.value}/"
  tags         = merge(var.tags, { Purpose = "${each.key}-catalog" })
}

resource "aws_athena_workgroup" "analytics" {
  name          = "${var.resource_prefix}-analytics"
  description   = "Cost-controlled ad hoc and lake transformation queries for ${var.environment}"
  force_destroy = var.environment == "sandbox"
  state         = "ENABLED"

  configuration {
    bytes_scanned_cutoff_per_query     = var.bytes_scanned_cutoff_per_query
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    requester_pays_enabled             = false

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      expected_bucket_owner = var.aws_account_id
      output_location       = "s3://${var.athena_results_bucket_id}/analytics/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = merge(var.tags, { Purpose = "lake-analytics" })
}
