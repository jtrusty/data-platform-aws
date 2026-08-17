locals {
  nonprod_environments = {
    sandbox = {
      account_id = local.workload_accounts.sandbox
      prefix     = "data-platform-sandbox"
      catalog    = "data_platform_sandbox"
      secret     = "data-platform/sandbox"
    }
    development = {
      account_id = local.workload_accounts.development
      prefix     = "data-platform-development"
      catalog    = "data_platform_development"
      secret     = "data-platform/development"
    }
  }
  production_environment = {
    account_id = local.workload_accounts.production
    prefix     = "data-platform-production"
    catalog    = "data_platform_production"
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

  # The Glue console enumerates candidate sources, VPC networking, KMS aliases,
  # and job roles before it will let anyone build a connection or a job. These
  # mirror the read-only half of the AWS-managed AWSGlueConsoleFullAccess policy.
  #
  # Deliberately not adopted from that policy: ec2:CreateTags and ec2:DeleteTags,
  # because platform tags are what several conditions in this very policy match
  # on, so tag control is privilege control; ec2:RunInstances and
  # ec2:TerminateInstances and cloudformation stack mutation, because they create
  # billed resources; and s3:CreateBucket, which Terraform owns.
  data_engineer_discovery_actions = [
    "athena:List*",
    "cloudwatch:Describe*", "cloudwatch:Get*", "cloudwatch:List*", "cloudwatch:PutMetricData",
    "docdb-elastic:List*",
    "dynamodb:List*",
    "ec2:Describe*",
    "iam:GetRole", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:ListRoles",
    "kms:ListAliases",
    "rds:Describe*",
    "redshift:Describe*",
    "s3:ListAllMyBuckets",
    "secretsmanager:ListSecrets",
    "tag:GetResources",
    # Glue's resource model is inconsistent: many actions, including the Studio
    # authoring helpers, take no resource and can only be granted at "*". AWS
    # reached the same conclusion in AWSGlueConsoleFullAccess, which grants
    # glue:* on "*". The catalog security settings and development endpoints
    # remain denied, and Terraform's Bronze and Silver databases stay protected
    # by their own resource-scoped denies.
    "glue:*",
    "lambda:List*",
    "logs:Describe*", "logs:List*",
    "redshift-serverless:List*",
    "sqs:ListQueues",
    "states:List*",
  ]

  # Engineers operate the platform's own resources freely, always bounded by the
  # environment-prefixed ARNs these actions are attached to. What they must not
  # touch is the configuration that defines the security, durability, or cost
  # boundary, and that is denied explicitly in platform_boundary_denies rather
  # than withheld action by action.
  data_engineer_resource_actions = [
    "athena:*",
    "dynamodb:*",
    "lambda:*",
    "logs:*",
    "sqs:*",
    "states:*",
  ]

  data_engineer_s3_actions = ["s3:*"]

  # Sandbox and development share one set of statements. Emitting the identical
  # action lists twice previously consumed most of the 10,240-byte permission-set
  # quota; the union is the same access, since both accounts are non-production
  # and every Terraform-owned tag is administrator-controlled.
  nonprod_environment_statements = [
    {
      Sid      = "OperateNonProdResources"
      Effect   = "Allow"
      Action   = local.data_engineer_resource_actions
      Resource = flatten([for environment in values(local.nonprod_environments) : local.data_engineer_resource_arns[environment.prefix]])
    },
    {
      Sid    = "QueryNonProdRedshift"
      Effect = "Allow"
      Action = [
        "redshift-data:BatchExecuteStatement",
        "redshift-data:ExecuteStatement",
        "redshift-data:ListDatabases",
        "redshift-data:ListSchemas",
        "redshift-data:ListTables",
        "redshift-serverless:GetCredentials",
        "redshift-serverless:GetNamespace",
        "redshift-serverless:GetWorkgroup",
      ]
      Resource = flatten([
        for environment in values(local.nonprod_environments) : [
          "arn:aws:redshift-serverless:us-east-2:${environment.account_id}:namespace/*",
          "arn:aws:redshift-serverless:us-east-2:${environment.account_id}:workgroup/*",
        ]
      ])
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Platform"    = "data-platform"
          "aws:ResourceTag/Environment" = keys(local.nonprod_environments)
        }
      }
    },
    {
      Sid      = "OperateNonProdData"
      Effect   = "Allow"
      Action   = local.data_engineer_s3_actions
      Resource = flatten([for environment in values(local.nonprod_environments) : ["arn:aws:s3:::${environment.prefix}-*", "arn:aws:s3:::${environment.prefix}-*/*"]])
    },
    {
      Sid      = "ManageNonProdSecrets"
      Effect   = "Allow"
      Action   = ["secretsmanager:*"]
      Resource = [for environment in values(local.nonprod_environments) : "arn:aws:secretsmanager:us-east-2:${environment.account_id}:secret:${environment.secret}/*"]
    },
    {
      Sid      = "UseNonProdDataKeys"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*"]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Platform"    = "data-platform"
          "aws:ResourceTag/Environment" = keys(local.nonprod_environments)
        }
      }
    },
    {
      Sid      = "DenyNonProdStateKeys"
      Effect   = "Deny"
      Action   = "kms:*"
      Resource = "*"
      Condition = {
        "ForAnyValue:StringLike" = {
          "kms:ResourceAliases" = [for name in keys(local.nonprod_environments) : "alias/jtrusty-data-platform-tfstate-${name}"]
        }
      }
    },
  ]

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
        "redshift-data:ListDatabases",
        "redshift-data:ListSchemas",
        "redshift-data:ListTables",
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
      Sid      = "ManageProductionSecrets"
      Effect   = "Allow"
      Action   = ["secretsmanager:*"]
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

  # Terraform owns the cost-controlled Athena workgroup and the Bronze/Silver
  # catalog databases. Broad athena:* and glue:*Database on the platform prefix
  # would otherwise let an engineer delete the query cost cap or a catalog.
  # The matching region deny is attached as a customer-managed policy instead of
  # inline text so these documents stay inside the 10,240-byte quota.
  # glue:* is granted on the platform's own Glue resources, so the catalog-wide
  # security settings are denied explicitly. A catalog resource policy can grant
  # another account access to the whole catalog.
  platform_boundary_denies = [
    {
      Sid    = "ProtectResourcePoliciesAndPublicAccess"
      Effect = "Deny"
      Action = [
        "dynamodb:PutResourcePolicy",
        "glue:DeleteResourcePolicy",
        "glue:PutDataCatalogEncryptionSettings",
        "glue:PutResourcePolicy",
        "lambda:*FunctionUrlConfig",
        "lambda:AddPermission",
        "s3:DeleteBucketPolicy",
        "s3:PutBucketAcl",
        "s3:PutBucketOwnershipControls",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutReplicationConfiguration",
        "secretsmanager:*ResourcePolicy",
        "secretsmanager:ReplicateSecretToRegions",
        "sqs:AddPermission",
        "sqs:RemovePermission",
      ]
      Resource = "*"
    },
    # Every action below moves platform data out of the account or the Region.
    # The region deny cannot stop them: the destination is a request parameter,
    # not the Region the call is made in.
    {
      Sid    = "ProtectAgainstDataMovement"
      Effect = "Deny"
      Action = [
        "dynamodb:CreateGlobalTable",
        "dynamodb:CreateTableReplica",
        "dynamodb:UpdateGlobalTable*",
        "logs:PutDestination*",
        "logs:PutSubscriptionFilter",
      ]
      Resource = "*"
    },
    {
      Sid    = "ProtectDurabilityAndRetention"
      Effect = "Deny"
      Action = [
        "logs:DeleteRetentionPolicy",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:DeleteObjectVersion",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
      ]
      Resource = "*"
    },
    # Terraform owns the cost caps. An engineer-made Athena workgroup would have
    # no per-query scan cutoff and would not be watched by the monthly spend
    # guard, and Glue development endpoints and provisioned concurrency bill by
    # the hour whether or not anything uses them.
    {
      Sid    = "ProtectCostControls"
      Effect = "Deny"
      Action = [
        "athena:CreateWorkGroup",
        "athena:UpdateWorkGroup",
        "glue:*DevEndpoint",
        "lambda:PutProvisionedConcurrencyConfig",
      ]
      Resource = "*"
    },
  ]

  terraform_owned_analytics_denies = {
    for name, environment in local.protected_environments : name => [
      {
        Sid    = "Protect${replace(title(name), "-", "")}TerraformAnalytics"
        Effect = "Deny"
        Action = ["athena:DeleteWorkGroup", "athena:UpdateWorkGroup", "glue:DeleteDatabase", "glue:UpdateDatabase"]
        Resource = [
          "arn:aws:athena:us-east-2:${environment.account_id}:workgroup/${environment.prefix}-analytics",
          "arn:aws:glue:us-east-2:${environment.account_id}:database/${environment.catalog}_bronze",
          "arn:aws:glue:us-east-2:${environment.account_id}:database/${environment.catalog}_silver",
        ]
      },
    ]
  }

  protected_environments = {
    development = local.nonprod_environments.development
    production  = local.production_environment
  }

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
      "arn:aws:glue:us-east-2:${environment.account_id}:connection/*",
      "arn:aws:glue:us-east-2:${environment.account_id}:crawler/${environment.prefix}-*",
      "arn:aws:glue:us-east-2:${environment.account_id}:database/${environment.catalog}*",
      "arn:aws:glue:us-east-2:${environment.account_id}:job/${environment.prefix}-*",
      "arn:aws:glue:us-east-2:${environment.account_id}:table/${environment.catalog}*/*",
      "arn:aws:lambda:us-east-2:${environment.account_id}:function:${environment.prefix}-*",
      "arn:aws:logs:us-east-2:${environment.account_id}:log-group:/aws-glue/*",
      "arn:aws:logs:us-east-2:${environment.account_id}:log-group:/aws/lambda/${environment.prefix}-*:*",
      "arn:aws:logs:us-east-2:${environment.account_id}:log-group:/aws/redshift/${environment.prefix}-warehouse/*",
      "arn:aws:logs:us-east-2:${environment.account_id}:log-group:/aws/redshift/${environment.prefix}-warehouse/*:*",
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
      local.terraform_owned_analytics_denies.development,
      local.platform_boundary_denies,
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
      local.terraform_owned_analytics_denies.production,
      local.platform_boundary_denies,
    )
  })

  read_owned_redshift_statements = {
    Sid    = "ReadOwnedRedshiftStatements"
    Effect = "Allow"
    Action = [
      "redshift-data:CancelStatement",
      "redshift-data:DescribeStatement",
      "redshift-data:GetStatementResult",
      "redshift-data:ListStatements",
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
