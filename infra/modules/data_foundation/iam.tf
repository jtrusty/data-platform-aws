locals {
  catalog_prefix = replace(var.resource_prefix, "-", "_")
  runtime_trusted_services = {
    ingest        = ["glue.amazonaws.com", "lambda.amazonaws.com"]
    transform     = ["glue.amazonaws.com", "lambda.amazonaws.com"]
    orchestration = ["states.amazonaws.com"]
    redshift      = ["redshift-serverless.amazonaws.com", "redshift.amazonaws.com"]
  }

  bucket_arns = {
    for purpose, bucket in module.platform_bucket : purpose => "arn:aws:s3:::${bucket.id}"
  }

  metadata_table_arn = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${aws_dynamodb_table.metadata.name}"
  source_secret_arns = [
    for name, secret in aws_secretsmanager_secret.platform : secret.arn
    if startswith(name, "sources/")
  ]
  lambda_log_arns = [
    "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.resource_prefix}-*",
    "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.resource_prefix}-*:log-stream:*",
  ]
  glue_log_arns = [
    "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws-glue/jobs/*",
    "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws-glue/jobs/*:log-stream:*",
  ]

  runtime_policy_statements = {
    ingest = concat(
      [
        {
          Sid      = "ReadLandingAndBronzeBuckets"
          Effect   = "Allow"
          Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
          Resource = [local.bucket_arns.landing, local.bucket_arns.bronze, local.bucket_arns.artifacts]
        },
        {
          Sid      = "ReadWriteLandingAndBronzeObjects"
          Effect   = "Allow"
          Action   = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
          Resource = ["${local.bucket_arns.landing}/*", "${local.bucket_arns.bronze}/*"]
        },
        {
          Sid      = "ReadIngestArtifacts"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:GetObjectVersion"]
          Resource = "${local.bucket_arns.artifacts}/*"
        },
        {
          Sid    = "UpdateIngestionMetadata"
          Effect = "Allow"
          Action = [
            "dynamodb:ConditionCheckItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:Query",
            "dynamodb:UpdateItem",
          ]
          Resource = local.metadata_table_arn
        },
        {
          Sid    = "ConsumeIngestQueue"
          Effect = "Allow"
          Action = [
            "sqs:ChangeMessageVisibility",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl",
            "sqs:ReceiveMessage",
          ]
          Resource = local.queue_arns.ingest
        },
        {
          Sid      = "PublishBronzeCompletion"
          Effect   = "Allow"
          Action   = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:SendMessage"]
          Resource = local.queue_arns["bronze-complete"]
        },
        {
          Sid      = "WriteIngestLogs"
          Effect   = "Allow"
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = concat(local.lambda_log_arns, local.glue_log_arns)
        },
      ],
      length(local.source_secret_arns) == 0 ? [] : [
        {
          Sid      = "ReadSourceSecrets"
          Effect   = "Allow"
          Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
          Resource = local.source_secret_arns
        },
      ],
    )

    transform = [
      {
        Sid      = "ReadBronzeBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = [local.bucket_arns.bronze, local.bucket_arns.artifacts]
      },
      {
        Sid      = "ReadBronzeObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${local.bucket_arns.bronze}/*"
      },
      {
        Sid      = "ReadTransformArtifacts"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${local.bucket_arns.artifacts}/*"
      },
      {
        Sid      = "ReadWriteSilverBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = local.bucket_arns.silver
      },
      {
        Sid      = "ReadWriteSilverObjects"
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = "${local.bucket_arns.silver}/*"
      },
      {
        Sid      = "UseAthenaResultsBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = local.bucket_arns["athena-results"]
      },
      {
        Sid      = "UseAthenaResultObjects"
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:PutObject"]
        Resource = "${local.bucket_arns["athena-results"]}/*"
      },
      {
        Sid    = "ConsumeBronzeCompletion"
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = local.queue_arns["bronze-complete"]
      },
      {
        Sid    = "OperateTransformationCatalog"
        Effect = "Allow"
        Action = [
          "glue:BatchCreatePartition",
          "glue:CreatePartition",
          "glue:CreateTable",
          "glue:DeletePartition",
          "glue:DeleteTable",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetTable",
          "glue:GetTables",
          "glue:UpdatePartition",
          "glue:UpdateTable",
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:database/${local.catalog_prefix}*",
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:table/${local.catalog_prefix}*/*",
        ]
      },
      {
        Sid    = "RunTransformationQueries"
        Effect = "Allow"
        Action = [
          "athena:GetDataCatalog",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetWorkGroup",
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
        ]
        Resource = [
          "arn:aws:athena:${var.aws_region}:${var.aws_account_id}:datacatalog/AwsDataCatalog",
          "arn:aws:athena:${var.aws_region}:${var.aws_account_id}:workgroup/${var.resource_prefix}-*",
        ]
      },
      {
        Sid      = "WriteTransformLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = concat(local.lambda_log_arns, local.glue_log_arns)
      },
    ]

    orchestration = [
      {
        Sid      = "InvokePlatformFunctions"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.resource_prefix}-*"
      },
      {
        Sid      = "RunPlatformGlueJobs"
        Effect   = "Allow"
        Action   = ["glue:BatchStopJobRun", "glue:GetJobRun", "glue:GetJobRuns", "glue:StartJobRun"]
        Resource = "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:job/${var.resource_prefix}-*"
      },
      {
        Sid    = "RunPlatformQueries"
        Effect = "Allow"
        Action = [
          "athena:GetQueryExecution",
          "athena:GetWorkGroup",
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
        ]
        Resource = "arn:aws:athena:${var.aws_region}:${var.aws_account_id}:workgroup/${var.resource_prefix}-*"
      },
      {
        Sid      = "PublishPlatformMessages"
        Effect   = "Allow"
        Action   = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:SendMessage"]
        Resource = values(local.queue_arns)
      },
      {
        Sid      = "ReadOrchestrationQueryBuckets"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = [local.bucket_arns.bronze, local.bucket_arns.silver, local.bucket_arns["athena-results"]]
      },
      {
        Sid      = "ReadOrchestrationSourceObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${local.bucket_arns.bronze}/*"
      },
      {
        Sid      = "WriteOrchestrationQueryObjects"
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = ["${local.bucket_arns.silver}/*", "${local.bucket_arns["athena-results"]}/*"]
      },
      {
        Sid    = "ReadOrchestrationCatalog"
        Effect = "Allow"
        Action = ["glue:GetDatabase", "glue:GetDatabases", "glue:GetPartition", "glue:GetPartitions", "glue:GetTable", "glue:GetTables"]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:database/${local.catalog_prefix}*",
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:table/${local.catalog_prefix}*/*",
        ]
      },
      {
        Sid    = "StartPlatformRedshiftStatements"
        Effect = "Allow"
        Action = [
          "redshift-data:BatchExecuteStatement",
          "redshift-data:ExecuteStatement",
          "redshift-serverless:GetCredentials",
        ]
        Resource = [
          "arn:aws:redshift-serverless:${var.aws_region}:${var.aws_account_id}:workgroup/*",
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "ReadOwnedRedshiftStatements"
        Effect = "Allow"
        Action = [
          "redshift-data:CancelStatement",
          "redshift-data:DescribeStatement",
          "redshift-data:GetStatementResult",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "redshift-data:statement-owner-iam-userid" = "$${aws:userid}"
          }
        }
      },
    ]

    redshift = [
      {
        Sid      = "ReadSilverBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = local.bucket_arns.silver
      },
      {
        Sid      = "ReadSilverObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${local.bucket_arns.silver}/*"
      },
      {
        Sid    = "ReadPlatformCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetTable",
          "glue:GetTables",
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:database/${local.catalog_prefix}*",
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:table/${local.catalog_prefix}*/*",
        ]
      },
    ]
  }
}

resource "aws_iam_role" "runtime" {
  for_each = local.runtime_trusted_services

  name                 = "${var.resource_prefix}-${each.key}"
  path                 = "/data-platform/runtime/"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [merge(
      {
        Sid       = "TrustApprovedServices"
        Effect    = "Allow"
        Principal = { Service = each.value }
        Action    = "sts:AssumeRole"
      },
      each.key == "redshift" ? {
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      } : {},
    )]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "runtime" {
  for_each = aws_iam_role.runtime

  name = "${var.resource_prefix}-${each.key}-runtime"
  role = each.value.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.runtime_policy_statements[each.key]
  })
}

# The Athena spend guard is a platform control rather than a data-plane role, so
# it is defined separately from the four responsibility-based runtime roles.
resource "aws_iam_role" "athena_guard" {
  name                 = "${var.resource_prefix}-athena-guard"
  path                 = "/data-platform/runtime/"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "TrustLambda"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "athena_guard" {
  name = "${var.resource_prefix}-athena-guard"
  role = aws_iam_role.athena_guard.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadAthenaSpendMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics"]
        Resource = "*"
      },
      {
        Sid      = "DisableOverspendingWorkgroup"
        Effect   = "Allow"
        Action   = ["athena:GetWorkGroup", "athena:UpdateWorkGroup"]
        Resource = "arn:aws:athena:${var.aws_region}:${var.aws_account_id}:workgroup/${var.resource_prefix}-*"
      },
      {
        Sid      = "WriteSpendGuardLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = local.lambda_log_arns
      },
    ]
  })
}
