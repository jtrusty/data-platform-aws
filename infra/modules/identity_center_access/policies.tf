locals {
  nonprod_environments = {
    sandbox = {
      account_id = local.workload_accounts.sandbox
      prefix     = "data-platform-sandbox"
      secret     = "data-platform/sandbox"
    }
    development = {
      account_id = local.workload_accounts.development
      prefix     = "data-platform-development"
      secret     = "data-platform/development"
    }
  }
  production_environment = {
    account_id = local.workload_accounts.production
    prefix     = "data-platform-production"
    secret     = "data-platform/production"
  }

  nonprod_runtime_roles = flatten([
    for environment in values(local.nonprod_environments) : [
      "arn:aws:iam::${environment.account_id}:role/data-platform/runtime/${environment.prefix}-ingest",
      "arn:aws:iam::${environment.account_id}:role/data-platform/runtime/${environment.prefix}-transform",
      "arn:aws:iam::${environment.account_id}:role/data-platform/runtime/${environment.prefix}-orchestration",
      "arn:aws:iam::${environment.account_id}:role/data-platform/runtime/${environment.prefix}-redshift",
    ]
  ])

  production_runtime_roles = [
    "arn:aws:iam::${local.production_environment.account_id}:role/data-platform/runtime/${local.production_environment.prefix}-ingest",
    "arn:aws:iam::${local.production_environment.account_id}:role/data-platform/runtime/${local.production_environment.prefix}-transform",
    "arn:aws:iam::${local.production_environment.account_id}:role/data-platform/runtime/${local.production_environment.prefix}-orchestration",
    "arn:aws:iam::${local.production_environment.account_id}:role/data-platform/runtime/${local.production_environment.prefix}-redshift",
  ]

  data_engineer_discovery_actions = [
    "athena:List*",
    "cloudwatch:Describe*", "cloudwatch:Get*", "cloudwatch:List*", "cloudwatch:PutMetricData",
    "dynamodb:List*",
    "glue:List*",
    "lambda:List*",
    "logs:Describe*", "logs:List*",
    "redshift-data:List*",
    "redshift-serverless:List*",
    "sqs:ListQueues",
    "states:List*",
  ]

  data_engineer_resource_actions = [
    "athena:*",
    "dynamodb:*Item*", "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:Describe*",
    "dynamodb:Query", "dynamodb:Scan", "dynamodb:TagResource", "dynamodb:UntagResource", "dynamodb:UpdateTable",
    "glue:*Crawler", "glue:*Database", "glue:*Job", "glue:*Partition", "glue:*Table",
    "glue:Get*", "glue:StartJobRun", "glue:StopJobRun", "glue:TagResource", "glue:UntagResource",
    "lambda:CreateFunction", "lambda:DeleteFunction", "lambda:Get*", "lambda:PublishVersion",
    "lambda:TagResource", "lambda:UntagResource", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
    "logs:FilterLogEvents", "logs:Get*", "logs:StartQuery", "logs:StopQuery",
    "sqs:*Message*", "sqs:CreateQueue", "sqs:DeleteQueue", "sqs:GetQueueAttributes", "sqs:GetQueueUrl",
    "sqs:ListDeadLetterSourceQueues", "sqs:ListQueueTags", "sqs:PurgeQueue", "sqs:TagQueue", "sqs:UntagQueue",
    "states:*",
  ]

  data_engineer_s3_actions = [
    "s3:AbortMultipartUpload", "s3:DeleteObject", "s3:GetBucketLocation", "s3:GetObject",
    "s3:GetObjectAttributes", "s3:GetObjectVersion", "s3:ListBucket", "s3:ListBucketVersions",
    "s3:ListMultipartUploadParts", "s3:PutObject", "s3:RestoreObject",
  ]

  nonprod_environment_statements = flatten([
    for name, environment in local.nonprod_environments : [
      {
        Sid      = "Operate${replace(title(name), "-", "")}Resources"
        Effect   = "Allow"
        Action   = local.data_engineer_resource_actions
        Resource = local.data_engineer_resource_arns[environment.prefix]
      },
      {
        Sid    = "Query${replace(title(name), "-", "")}Redshift"
        Effect = "Allow"
        Action = [
          "redshift-data:BatchExecuteStatement",
          "redshift-data:ExecuteStatement",
          "redshift-serverless:GetCredentials",
          "redshift-serverless:GetNamespace",
          "redshift-serverless:GetWorkgroup",
        ]
        Resource = [
          "arn:aws:redshift-serverless:us-east-2:${environment.account_id}:namespace/*",
          "arn:aws:redshift-serverless:us-east-2:${environment.account_id}:workgroup/*",
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = name
          }
        }
      },
      {
        Sid      = "Operate${replace(title(name), "-", "")}Data"
        Effect   = "Allow"
        Action   = local.data_engineer_s3_actions
        Resource = ["arn:aws:s3:::${environment.prefix}-*", "arn:aws:s3:::${environment.prefix}-*/*"]
      },
      {
        Sid      = "Read${replace(title(name), "-", "")}Secrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:ListSecretVersionIds"]
        Resource = "arn:aws:secretsmanager:us-east-2:${environment.account_id}:secret:${environment.secret}/*"
      },
      {
        Sid      = "Use${replace(title(name), "-", "")}DataKeys"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = name
          }
        }
      },
      {
        Sid      = "Deny${replace(title(name), "-", "")}StateKey"
        Effect   = "Deny"
        Action   = "kms:*"
        Resource = "*"
        Condition = {
          "ForAnyValue:StringLike" = {
            "kms:ResourceAliases" = "alias/jtrusty-data-platform-tfstate-${name}"
          }
        }
      },
    ]
  ])

  production_environment_statements = [
    {
      Sid      = "OperateProductionResources"
      Effect   = "Allow"
      Action   = local.data_engineer_resource_actions
      Resource = local.data_engineer_resource_arns[local.production_environment.prefix]
    },
    {
      Sid    = "QueryProductionRedshift"
      Effect = "Allow"
      Action = [
        "redshift-data:BatchExecuteStatement",
        "redshift-data:ExecuteStatement",
        "redshift-serverless:GetCredentials",
        "redshift-serverless:GetNamespace",
        "redshift-serverless:GetWorkgroup",
      ]
      Resource = [
        "arn:aws:redshift-serverless:us-east-2:${local.production_environment.account_id}:namespace/*",
        "arn:aws:redshift-serverless:us-east-2:${local.production_environment.account_id}:workgroup/*",
      ]
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Platform"    = "data-platform"
          "aws:ResourceTag/Environment" = "production"
        }
      }
    },
    {
      Sid    = "OperateProductionData"
      Effect = "Allow"
      Action = local.data_engineer_s3_actions
      Resource = [
        "arn:aws:s3:::${local.production_environment.prefix}-*",
        "arn:aws:s3:::${local.production_environment.prefix}-*/*",
      ]
    },
    {
      Sid      = "ReadProductionSecrets"
      Effect   = "Allow"
      Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:ListSecretVersionIds"]
      Resource = "arn:aws:secretsmanager:us-east-2:${local.production_environment.account_id}:secret:${local.production_environment.secret}/*"
    },
    {
      Sid      = "UseProductionDataKeys"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*"]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Platform"    = "data-platform"
          "aws:ResourceTag/Environment" = "production"
        }
      }
    },
    {
      Sid      = "DenyProductionStateKey"
      Effect   = "Deny"
      Action   = "kms:*"
      Resource = "*"
      Condition = {
        "ForAnyValue:StringLike" = {
          "kms:ResourceAliases" = "alias/jtrusty-data-platform-tfstate-production"
        }
      }
    },
  ]

  protected_development_resources = [
    {
      Sid      = "ProtectDevelopmentMetadata"
      Effect   = "Deny"
      Action   = ["dynamodb:DeleteTable"]
      Resource = "arn:aws:dynamodb:us-east-2:${local.workload_accounts.development}:table/data-platform-development-metadata"
    },
    {
      Sid    = "ProtectDevelopmentBaselineQueues"
      Effect = "Deny"
      Action = ["sqs:DeleteQueue", "sqs:PurgeQueue"]
      Resource = [
        "arn:aws:sqs:us-east-2:${local.workload_accounts.development}:data-platform-development-ingest",
        "arn:aws:sqs:us-east-2:${local.workload_accounts.development}:data-platform-development-ingest-dlq",
        "arn:aws:sqs:us-east-2:${local.workload_accounts.development}:data-platform-development-bronze-complete",
        "arn:aws:sqs:us-east-2:${local.workload_accounts.development}:data-platform-development-bronze-complete-dlq",
      ]
    },
  ]

  protected_production_resources = [
    {
      Sid      = "ProtectProductionMetadata"
      Effect   = "Deny"
      Action   = ["dynamodb:DeleteTable"]
      Resource = "arn:aws:dynamodb:us-east-2:${local.workload_accounts.production}:table/data-platform-production-metadata"
    },
    {
      Sid    = "ProtectProductionBaselineQueues"
      Effect = "Deny"
      Action = ["sqs:DeleteQueue", "sqs:PurgeQueue"]
      Resource = [
        "arn:aws:sqs:us-east-2:${local.workload_accounts.production}:data-platform-production-ingest",
        "arn:aws:sqs:us-east-2:${local.workload_accounts.production}:data-platform-production-ingest-dlq",
        "arn:aws:sqs:us-east-2:${local.workload_accounts.production}:data-platform-production-bronze-complete",
        "arn:aws:sqs:us-east-2:${local.workload_accounts.production}:data-platform-production-bronze-complete-dlq",
      ]
    },
  ]

  data_engineer_resource_arns = {
    for environment in concat(values(local.nonprod_environments), [local.production_environment]) : environment.prefix => [
      "arn:aws:athena:us-east-2:${environment.account_id}:datacatalog/AwsDataCatalog",
      "arn:aws:athena:us-east-2:${environment.account_id}:workgroup/${environment.prefix}-*",
      "arn:aws:dynamodb:us-east-2:${environment.account_id}:table/${environment.prefix}-*",
      "arn:aws:dynamodb:us-east-2:${environment.account_id}:table/${environment.prefix}-*/index/*",
      "arn:aws:glue:us-east-2:${environment.account_id}:catalog",
      "arn:aws:glue:us-east-2:${environment.account_id}:crawler/${environment.prefix}-*",
      "arn:aws:glue:us-east-2:${environment.account_id}:database/${environment.prefix}*",
      "arn:aws:glue:us-east-2:${environment.account_id}:job/${environment.prefix}-*",
      "arn:aws:glue:us-east-2:${environment.account_id}:table/${environment.prefix}*/*",
      "arn:aws:lambda:us-east-2:${environment.account_id}:function:${environment.prefix}-*",
      "arn:aws:logs:us-east-2:${environment.account_id}:log-group:/aws-glue/*",
      "arn:aws:logs:us-east-2:${environment.account_id}:log-group:/aws/lambda/${environment.prefix}-*:*",
      "arn:aws:sqs:us-east-2:${environment.account_id}:${environment.prefix}-*",
      "arn:aws:states:us-east-2:${environment.account_id}:execution:${environment.prefix}-*:*",
      "arn:aws:states:us-east-2:${environment.account_id}:stateMachine:${environment.prefix}-*",
    ]
  }

  data_engineer_nonprod_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{ Sid = "DiscoverPlatformResources", Effect = "Allow", Action = local.data_engineer_discovery_actions, Resource = "*" }],
      local.nonprod_environment_statements,
      [local.read_owned_redshift_statements],
      local.passrole_statements_nonprod,
      local.protected_development_resources,
    )
  })

  data_engineer_production_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{ Sid = "DiscoverPlatformResources", Effect = "Allow", Action = local.data_engineer_discovery_actions, Resource = "*" }],
      local.production_environment_statements,
      [local.read_owned_redshift_statements],
      local.passrole_statements_production,
      local.protected_production_resources,
    )
  })

  read_owned_redshift_statements = {
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
  }

  passrole_statements_nonprod = [
    {
      Sid       = "PassIngestAndTransformRoles"
      Effect    = "Allow"
      Action    = ["iam:PassRole"]
      Resource  = [for arn in local.nonprod_runtime_roles : arn if endswith(arn, "-ingest") || endswith(arn, "-transform")]
      Condition = { StringEquals = { "iam:PassedToService" = ["glue.amazonaws.com", "lambda.amazonaws.com"] } }
    },
    {
      Sid       = "PassOrchestrationRoles"
      Effect    = "Allow"
      Action    = ["iam:PassRole"]
      Resource  = [for arn in local.nonprod_runtime_roles : arn if endswith(arn, "-orchestration")]
      Condition = { StringEquals = { "iam:PassedToService" = ["states.amazonaws.com"] } }
    },
    {
      Sid       = "PassRedshiftRoles"
      Effect    = "Allow"
      Action    = ["iam:PassRole"]
      Resource  = [for arn in local.nonprod_runtime_roles : arn if endswith(arn, "-redshift")]
      Condition = { StringEquals = { "iam:PassedToService" = ["redshift-serverless.amazonaws.com"] } }
    },
  ]

  passrole_statements_production = [
    {
      Sid       = "PassIngestAndTransformRoles"
      Effect    = "Allow"
      Action    = ["iam:PassRole"]
      Resource  = [for arn in local.production_runtime_roles : arn if endswith(arn, "-ingest") || endswith(arn, "-transform")]
      Condition = { StringEquals = { "iam:PassedToService" = ["glue.amazonaws.com", "lambda.amazonaws.com"] } }
    },
    {
      Sid       = "PassOrchestrationRole"
      Effect    = "Allow"
      Action    = ["iam:PassRole"]
      Resource  = [for arn in local.production_runtime_roles : arn if endswith(arn, "-orchestration")]
      Condition = { StringEquals = { "iam:PassedToService" = ["states.amazonaws.com"] } }
    },
    {
      Sid       = "PassRedshiftRole"
      Effect    = "Allow"
      Action    = ["iam:PassRole"]
      Resource  = [for arn in local.production_runtime_roles : arn if endswith(arn, "-redshift")]
      Condition = { StringEquals = { "iam:PassedToService" = ["redshift-serverless.amazonaws.com"] } }
    },
  ]
}
