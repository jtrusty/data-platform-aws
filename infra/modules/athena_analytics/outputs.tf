output "workgroup_name" {
  description = "Cost-controlled Athena workgroup name."
  value       = aws_athena_workgroup.analytics.name
}

output "workgroup_arn" {
  description = "Cost-controlled Athena workgroup ARN."
  value       = aws_athena_workgroup.analytics.arn
}

output "catalog_database_names" {
  description = "Glue Catalog database names keyed by lake layer."
  value       = { for layer, database in aws_glue_catalog_database.layer : layer => database.name }
}

output "bytes_scanned_cutoff_per_query" {
  description = "Hard per-query Athena scan limit in bytes."
  value       = var.bytes_scanned_cutoff_per_query
}
