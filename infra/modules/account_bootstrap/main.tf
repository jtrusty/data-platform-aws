locals {
  immutable_subject = "repo:${var.github_repository_owner}@${var.github_owner_id}/${var.github_repository_name}@${var.github_repository_id}:environment:${var.github_environment}"
  role_prefix       = "data-platform-${var.environment}"
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

module "state_backend" {
  source = "../state_backend"

  account_id  = var.account_id
  environment = var.environment
  tags        = var.tags
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
          "redshift-data:DescribeStatement",
          "redshift-data:ExecuteStatement",
          "redshift-data:GetStatementResult",
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
        ]
        Resource = [
          "arn:aws:athena:us-east-2:${var.account_id}:workgroup/data-platform-${var.environment}-*",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/data-platform-${var.environment}-*",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/data-platform-${var.environment}-*/index/*",
          "arn:aws:glue:us-east-2:${var.account_id}:catalog",
          "arn:aws:glue:us-east-2:${var.account_id}:database/data-platform-${var.environment}*",
          "arn:aws:glue:us-east-2:${var.account_id}:job/data-platform-${var.environment}-*",
          "arn:aws:glue:us-east-2:${var.account_id}:table/data-platform-${var.environment}*/*",
          "arn:aws:lambda:us-east-2:${var.account_id}:function:data-platform-${var.environment}-*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws/lambda/data-platform-${var.environment}-*:*",
          "arn:aws:redshift-serverless:us-east-2:${var.account_id}:namespace/data-platform-${var.environment}-*",
          "arn:aws:redshift-serverless:us-east-2:${var.account_id}:workgroup/data-platform-${var.environment}-*",
          "arn:aws:sqs:us-east-2:${var.account_id}:data-platform-${var.environment}-*",
        ]
      },
      {
        Sid    = "PlatformRuntimeData"
        Effect = "Allow"
        Action = ["s3:AbortMultipartUpload", "s3:GetObject*", "s3:ListBucket", "s3:PutObject*"]
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

resource "aws_iam_role" "terraform_plan" {
  count = var.environment == "production" ? 1 : 0

  name = "jtrusty-data-platform-terraform-plan-production"
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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository_owner}@${var.github_owner_id}/${var.github_repository_name}@${var.github_repository_id}:environment:production-plan"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "terraform_plan" {
  count = var.environment == "production" ? 1 : 0

  name = "terraform-plan-production"
  role = aws_iam_role.terraform_plan[0].id
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
          "redshift-serverless:GetCustomDomainAssociation", "redshift-serverless:GetEndpointAccess",
          "redshift-serverless:GetNamespace", "redshift-serverless:GetRecoveryPoint",
          "redshift-serverless:GetResourcePolicy", "redshift-serverless:GetSnapshot",
          "redshift-serverless:GetTableRestoreStatus", "redshift-serverless:GetUsageLimit",
          "redshift-serverless:GetWorkgroup", "secretsmanager:DescribeSecret",
          "sqs:Get*", "states:DescribeStateMachine",
        ]
        Resource = [
          "arn:aws:athena:us-east-2:${var.account_id}:workgroup/data-platform-production-*",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/data-platform-production-*",
          "arn:aws:dynamodb:us-east-2:${var.account_id}:table/data-platform-production-*/index/*",
          "arn:aws:glue:us-east-2:${var.account_id}:catalog",
          "arn:aws:glue:us-east-2:${var.account_id}:crawler/data-platform-production-*",
          "arn:aws:glue:us-east-2:${var.account_id}:database/data-platform-production*",
          "arn:aws:glue:us-east-2:${var.account_id}:job/data-platform-production-*",
          "arn:aws:glue:us-east-2:${var.account_id}:table/data-platform-production*/*",
          "arn:aws:iam::${var.account_id}:policy/data-platform/runtime/data-platform-production-*",
          "arn:aws:iam::${var.account_id}:role/data-platform/runtime/data-platform-production-*",
          "arn:aws:lambda:us-east-2:${var.account_id}:function:data-platform-production-*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:us-east-2:${var.account_id}:log-group:/aws/lambda/data-platform-production-*:*",
          "arn:aws:redshift-serverless:us-east-2:${var.account_id}:namespace/data-platform-production-*",
          "arn:aws:redshift-serverless:us-east-2:${var.account_id}:workgroup/data-platform-production-*",
          "arn:aws:secretsmanager:us-east-2:${var.account_id}:secret:data-platform/production/*",
          "arn:aws:sqs:us-east-2:${var.account_id}:data-platform-production-*",
          "arn:aws:states:us-east-2:${var.account_id}:execution:data-platform-production-*:*",
          "arn:aws:states:us-east-2:${var.account_id}:stateMachine:data-platform-production-*",
        ]
      },
      {
        Sid      = "ReadPlatformKeys"
        Effect   = "Allow"
        Action   = ["kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = "production"
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
        Resource = ["arn:aws:s3:::data-platform-production-*"]
      },
    ]
  })
}
