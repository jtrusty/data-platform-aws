locals {
  github_repository_subject = "repo:${var.github_repository_owner}@${var.github_owner_id}/${var.github_repository_name}@${var.github_repository_id}"
  immutable_subject         = "${local.github_repository_subject}:environment:${var.github_environment}"
  immutable_plan_subject    = "${local.github_repository_subject}:environment:${var.environment}-plan"
  role_prefix               = "data-platform-${var.environment}"
  catalog_prefix            = "data_platform_${var.environment}"
  runtime_role_arns = {
    ingest        = "arn:aws:iam::${var.account_id}:role/data-platform/runtime/${local.role_prefix}-ingest"
    transform     = "arn:aws:iam::${var.account_id}:role/data-platform/runtime/${local.role_prefix}-transform"
    orchestration = "arn:aws:iam::${var.account_id}:role/data-platform/runtime/${local.role_prefix}-orchestration"
    redshift      = "arn:aws:iam::${var.account_id}:role/data-platform/runtime/${local.role_prefix}-redshift"
  }
  state_key               = "data-platform/${var.environment}/terraform.tfstate"
  state_object_arn        = "${module.state_backend.bucket_arn}/${local.state_key}"
  lock_object_arn         = "${local.state_object_arn}.tflock"
  runtime_boundary_arn    = "arn:aws:iam::${var.account_id}:policy/bootstrap/jtrusty-data-platform-runtime-boundary-${var.environment}"
  deployment_boundary_arn = "arn:aws:iam::${var.account_id}:policy/bootstrap/jtrusty-data-platform-deployment-boundary-${var.environment}"
}

moved {
  from = aws_iam_service_linked_role.redshift
  to   = aws_iam_service_linked_role.redshift[0]
}

moved {
  from = aws_iam_role.terraform_plan[0]
  to   = aws_iam_role.terraform_plan
}

moved {
  from = aws_iam_role_policy.terraform_plan[0]
  to   = aws_iam_role_policy.terraform_plan
}

module "state_backend" {
  source = "../state_backend"

  account_id  = var.account_id
  environment = var.environment
  tags        = var.tags
}

# The Redshift service-linked role is account-wide and already exists in any
# account that has ever used Redshift, where creating it fails. Deleting it
# would break unrelated Redshift usage, so it is also protected from destroy.
resource "aws_iam_service_linked_role" "redshift" {
  count = var.manage_redshift_service_linked_role ? 1 : 0

  aws_service_name = "redshift.amazonaws.com"
  description      = "Allows Amazon Redshift and Redshift Serverless to manage required account resources"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = merge(var.tags, { Purpose = "github-oidc" })
}

resource "aws_iam_policy" "runtime_boundary" {
  name        = "jtrusty-data-platform-runtime-boundary-${var.environment}"
  path        = "/bootstrap/"
  description = "Maximum permissions for data platform runtime roles"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PlatformRuntimeServices"
        Effect = "Allow"
        Action = [
          "athena:Get*",
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "glue:Get*",
          "glue:BatchGet*",
          "glue:BatchStopJobRun",
          "glue:CreatePartition",
          "glue:BatchCreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:StartJobRun",
          "lambda:InvokeFunction",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
        ]
        Resource = [
          "arn:aws:athena:us-east-2:${var.account_id}:workgroup/data-platform-${var.environment}-*",
          "arn:aws:athena:us-east-2:${var.account_id}:datacatalog/AwsDataCatalog",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/data-platform-${var.environment}-*",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/data-platform-${var.environment}-*/index/*",
          "arn:aws:glue:us-east-2:${var.account_id}:catalog",
          "arn:aws:glue:us-east-2:${var.account_id}:database/${local.catalog_prefix}*",
          "arn:aws:glue:us-east-2:${var.account_id}:job/data-platform-${var.environment}-*",
          "arn:aws:glue:us-east-2:${var.account_id}:table/${local.catalog_prefix}*/*",
          "arn:aws:lambda:us-east-2:${var.account_id}:function:data-platform-${var.environment}-*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws/lambda/data-platform-${var.environment}-*:*",
          "arn:aws:sqs:us-east-2:${var.account_id}:data-platform-${var.environment}-*",
        ]
      },
      {
        Sid      = "StartPlatformRedshiftStatements"
        Effect   = "Allow"
        Action   = ["redshift-data:BatchExecuteStatement", "redshift-data:ExecuteStatement"]
        Resource = "arn:aws:redshift-serverless:us-east-2:${var.account_id}:workgroup/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid      = "ReadPlatformRedshiftStatements"
        Effect   = "Allow"
        Action   = ["redshift-data:CancelStatement", "redshift-data:DescribeStatement", "redshift-data:GetStatementResult"]
        Resource = "*"
      },
      {
        Sid      = "GetPlatformRedshiftCredentials"
        Effect   = "Allow"
        Action   = ["redshift-serverless:GetCredentials"]
        Resource = "arn:aws:redshift-serverless:us-east-2:${var.account_id}:workgroup/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "PlatformRuntimeData"
        Effect = "Allow"
        Action = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket", "s3:PutObject"]
        Resource = [
          "arn:aws:s3:::data-platform-${var.environment}-*",
          "arn:aws:s3:::data-platform-${var.environment}-*/*",
        ]
      },
      {
        Sid      = "PlatformRuntimeSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:us-east-2:${var.account_id}:secret:data-platform/${var.environment}/*"
      },
      {
        Sid      = "PlatformRuntimeCryptography"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid      = "DenyTerraformStateData"
        Effect   = "Deny"
        Action   = "s3:*"
        Resource = [module.state_backend.bucket_arn, "${module.state_backend.bucket_arn}/*"]
      },
      {
        Sid      = "DenyTerraformStateKey"
        Effect   = "Deny"
        Action   = "kms:*"
        Resource = module.state_backend.kms_key_arn
      },
      local.region_guardrail_statement,
    ]
  })
  tags = var.tags
}

# Terraform must manage every S3 control on environment-prefixed platform buckets.
# The separate state namespace is explicitly excluded and covered by Terraform tests.
#trivy:ignore:AVD-AWS-0345:exp:2027-08-13
resource "aws_iam_policy" "deployment_boundary" {
  name        = "jtrusty-data-platform-deployment-boundary-${var.environment}"
  path        = "/bootstrap/"
  description = "Maximum permissions for the environment Terraform deployment role"
  policy      = local.terraform_deployment_policy
  tags        = var.tags
}

resource "aws_iam_policy" "deployment_guardrails" {
  name        = "jtrusty-data-platform-deployment-guardrails-${var.environment}"
  path        = "/bootstrap/"
  description = "Region and billed-resource denies applied to the environment Terraform deployment role"
  policy      = local.deployment_guardrail_policy
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "deployment_guardrails" {
  role       = aws_iam_role.terraform_deploy.name
  policy_arn = aws_iam_policy.deployment_guardrails.arn
}

# Attached to both DataEngineer permission sets by customer-managed reference so
# a federated session cannot create resources in an unused, unmonitored region.
resource "aws_iam_policy" "human_region_guardrail" {
  name        = "jtrusty-data-platform-region-guardrail"
  path        = "/data-platform/human/"
  description = "Denies human platform sessions outside the approved us-east-2 region"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [local.human_region_guardrail_statement]
  })
  tags = var.tags
}

resource "aws_iam_role" "terraform_deploy" {
  name                 = "jtrusty-data-platform-terraform-deploy-${var.environment}"
  path                 = "/bootstrap/"
  permissions_boundary = local.deployment_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.immutable_subject
        }
      }
    }]
  })
  tags = var.tags

  depends_on = [aws_iam_policy.deployment_boundary]
}

# Same reviewed policy as the boundary above; it is not account-wide S3 access.
#trivy:ignore:AVD-AWS-0345:exp:2027-08-13
resource "aws_iam_role_policy" "terraform_deploy" {
  name   = "terraform-deploy-${var.environment}"
  role   = aws_iam_role.terraform_deploy.id
  policy = local.terraform_deployment_policy
}

resource "aws_iam_role_policy" "protect_production_warehouse" {
  count = var.environment == "production" ? 1 : 0

  name = "protect-production-warehouse"
  role = aws_iam_role.terraform_deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ProtectProductionWarehouse"
      Effect   = "Deny"
      Action   = ["redshift-serverless:DeleteNamespace", "redshift-serverless:DeleteWorkgroup"]
      Resource = "*"
    }]
  })
}

# Every environment gets a read-only plan identity so pull requests can be
# planned and scheduled drift detection can run without an apply-capable
# credential. It is assumable only from the matching {environment}-plan
# GitHub Environment.
resource "aws_iam_role" "terraform_plan" {
  name = "jtrusty-data-platform-terraform-plan-${var.environment}"
  path = "/bootstrap/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.immutable_plan_subject
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "terraform_plan" {
  name = "terraform-plan-${var.environment}"
  role = aws_iam_role.terraform_plan.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadState"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = [local.state_object_arn]
      },
      {
        Sid      = "LockState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.lock_object_arn]
      },
      {
        Sid      = "ListState"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [module.state_backend.bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = [local.state_key, "${local.state_key}.tflock"] }
        }
      },
      {
        Sid      = "DecryptState"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = [module.state_backend.kms_key_arn]
      },
      {
        Sid    = "ReadPlatform"
        Effect = "Allow"
        Action = [
          "athena:List*", "cloudwatch:Get*", "cloudwatch:List*", "dynamodb:List*",
          "ec2:Describe*", "glue:List*", "iam:List*", "kms:Describe*", "kms:List*",
          "lambda:List*", "logs:Describe*", "logs:List*", "redshift-serverless:List*",
          "secretsmanager:ListSecrets", "sqs:List*", "states:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadPlatformResources"
        Effect = "Allow"
        Action = [
          "athena:GetDataCatalog", "athena:GetNamedQuery", "athena:GetPreparedStatement", "athena:GetWorkGroup",
          "dynamodb:Describe*", "glue:Get*", "iam:Get*", "lambda:Get*",
          "secretsmanager:DescribeSecret",
          "sqs:Get*", "states:DescribeStateMachine",
        ]
        Resource = [
          "arn:aws:athena:us-east-2:${var.account_id}:workgroup/${local.role_prefix}-*",
          "arn:aws:athena:us-east-2:${var.account_id}:datacatalog/AwsDataCatalog",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/${local.role_prefix}-*",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/${local.role_prefix}-*/index/*",
          "arn:aws:glue:us-east-2:${var.account_id}:catalog",
          "arn:aws:glue:us-east-2:${var.account_id}:crawler/${local.role_prefix}-*",
          "arn:aws:glue:us-east-2:${var.account_id}:database/${local.catalog_prefix}*",
          "arn:aws:glue:us-east-2:${var.account_id}:job/${local.role_prefix}-*",
          "arn:aws:glue:us-east-2:${var.account_id}:table/${local.catalog_prefix}*/*",
          "arn:aws:iam::${var.account_id}:policy/data-platform/runtime/${local.role_prefix}-*",
          "arn:aws:iam::${var.account_id}:role/data-platform/runtime/${local.role_prefix}-*",
          "arn:aws:lambda:us-east-2:${var.account_id}:function:${local.role_prefix}-*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws/lambda/${local.role_prefix}-*:*",
          "arn:aws:secretsmanager:us-east-2:${var.account_id}:secret:data-platform/${var.environment}/*",
          "arn:aws:sqs:us-east-2:${var.account_id}:${local.role_prefix}-*",
          "arn:aws:states:us-east-2:${var.account_id}:execution:${local.role_prefix}-*:*",
          "arn:aws:states:us-east-2:${var.account_id}:stateMachine:${local.role_prefix}-*",
        ]
      },
      {
        Sid    = "ReadRedshiftServerless"
        Effect = "Allow"
        Action = [
          "redshift-serverless:GetCustomDomainAssociation",
          "redshift-serverless:GetEndpointAccess",
          "redshift-serverless:GetNamespace",
          "redshift-serverless:GetRecoveryPoint",
          "redshift-serverless:GetResourcePolicy",
          "redshift-serverless:GetSnapshot",
          "redshift-serverless:GetTableRestoreStatus",
          "redshift-serverless:GetUsageLimit",
          "redshift-serverless:GetWorkgroup",
        ]
        Resource = "*"
      },
      {
        Sid      = "ReadPlatformKeys"
        Effect   = "Allow"
        Action   = ["kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid      = "DiscoverBuckets"
        Effect   = "Allow"
        Action   = ["s3:GetAccountPublicAccessBlock", "s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Sid    = "ReadPlatformBuckets"
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl", "s3:GetBucketCORS", "s3:GetBucketLocation", "s3:GetBucketLogging",
          "s3:GetBucketNotification", "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketOwnershipControls", "s3:GetBucketPolicy", "s3:GetBucketPolicyStatus",
          "s3:GetBucketPublicAccessBlock", "s3:GetBucketRequestPayment", "s3:GetBucketTagging",
          "s3:GetBucketVersioning", "s3:GetBucketWebsite", "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration",
          "s3:ListBucket", "s3:ListBucketVersions",
        ]
        Resource = ["arn:aws:s3:::${local.role_prefix}-*"]
      },
    ]
  })
}
