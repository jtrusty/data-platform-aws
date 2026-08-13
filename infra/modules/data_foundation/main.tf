locals {
  bucket_purposes = toset([
    "landing",
    "bronze",
    "silver",
    "artifacts",
    "athena-results",
  ])
  bucket_current_expiration = {
    landing        = var.landing_expiration_days
    bronze         = null
    silver         = null
    artifacts      = var.artifact_expiration_days
    athena-results = var.athena_results_expiration_days
  }
  queue_names = toset(["ingest", "bronze-complete"])
  queue_arns = {
    for name in local.queue_names :
    name => "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.resource_prefix}-${name}"
  }
  dead_letter_queue_arns = {
    for name in local.queue_names :
    name => "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.resource_prefix}-${name}-dlq"
  }
  secret_namespace = coalesce(var.secret_namespace, "data-platform/${var.environment}")
}

module "platform_bucket" {
  for_each = local.bucket_purposes

  source = "../secure_bucket"

  bucket_name           = "${var.resource_prefix}-${each.key}-${var.aws_account_id}"
  current_expiration    = local.bucket_current_expiration[each.key]
  force_destroy         = var.force_destroy_buckets
  noncurrent_expiration = var.noncurrent_version_expiration_days
  versioning_enabled    = contains(var.versioned_bucket_purposes, each.key)
  tags                  = merge(var.tags, { Purpose = each.key })
}

resource "aws_sqs_queue" "dead_letter" {
  for_each = local.queue_names

  name                      = "${var.resource_prefix}-${each.key}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  sqs_managed_sse_enabled   = true
  tags                      = merge(var.tags, { Purpose = "${each.key}-dead-letter" })
}

resource "aws_sqs_queue" "work" {
  for_each = local.queue_names

  name                       = "${var.resource_prefix}-${each.key}"
  message_retention_seconds  = var.queue_message_retention_seconds
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter[each.key].arn
    maxReceiveCount     = var.queue_max_receive_count
  })
  tags = merge(var.tags, { Purpose = each.key })
}

resource "aws_sqs_queue_redrive_allow_policy" "dead_letter" {
  for_each = local.queue_names

  queue_url = aws_sqs_queue.dead_letter[each.key].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.work[each.key].arn]
  })
}

resource "aws_sqs_queue_policy" "work" {
  for_each = local.queue_names

  queue_url = aws_sqs_queue.work[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "sqs:*"
      Resource  = local.queue_arns[each.key]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "dead_letter" {
  for_each = local.queue_names

  queue_url = aws_sqs_queue.dead_letter[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "sqs:*"
      Resource  = local.dead_letter_queue_arns[each.key]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

resource "aws_dynamodb_table" "metadata" {
  name           = "${var.resource_prefix}-metadata"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.metadata_read_capacity
  write_capacity = var.metadata_write_capacity
  hash_key       = "namespace"
  range_key      = "key"

  attribute {
    name = "namespace"
    type = "S"
  }

  attribute {
    name = "key"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.metadata_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = var.metadata_deletion_protection
  tags                        = merge(var.tags, { Purpose = "platform-metadata" })
}

resource "aws_secretsmanager_secret" "platform" {
  for_each = var.secret_names

  name                    = "${local.secret_namespace}/${each.key}"
  description             = "Secret container for ${var.environment} data platform ${each.key}"
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = merge(var.tags, { Purpose = "platform-secret" })
}
