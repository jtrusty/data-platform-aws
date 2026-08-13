locals {
  platform_service_actions = [
    "athena:*",
    "cloudwatch:*",
    "dynamodb:*",
    "ec2:*",
    "glue:*",
    "lambda:*",
    "logs:*",
    "redshift-data:*",
    "redshift-serverless:*",
    "sqs:*",
    "states:*",
  ]

  terraform_deployment_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PlatformServices"
        Effect   = "Allow"
        Action   = local.platform_service_actions
        Resource = "*"
      },
      {
        Sid    = "CreateAndDiscoverPlatformBuckets"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:GetAccountPublicAccessBlock",
          "s3:ListAllMyBuckets",
        ]
        Resource = "*"
      },
      {
        Sid    = "ManagePlatformBuckets"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::data-platform-${var.environment}-*",
          "arn:aws:s3:::data-platform-${var.environment}-*/*",
        ]
      },
      {
        Sid      = "DiscoverPlatformSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:ListSecrets"]
        Resource = "*"
      },
      {
        Sid      = "ManagePlatformSecrets"
        Effect   = "Allow"
        Action   = "secretsmanager:*"
        Resource = "arn:aws:secretsmanager:us-east-2:${var.account_id}:secret:data-platform/${var.environment}/*"
      },
      {
        Sid      = "CreateTaggedPlatformKeys"
        Effect   = "Allow"
        Action   = ["kms:CreateKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Platform"    = "data-platform"
            "aws:RequestTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "ManageTaggedPlatformKeys"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias", "kms:DeleteAlias", "kms:DescribeKey", "kms:DisableKeyRotation",
          "kms:EnableKeyRotation", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus",
          "kms:ListResourceTags", "kms:PutKeyPolicy", "kms:ScheduleKeyDeletion",
          "kms:TagResource", "kms:UntagResource", "kms:UpdateAlias", "kms:UpdateKeyDescription",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Platform"    = "data-platform"
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid      = "CreateBoundedRuntimeRoles"
        Effect   = "Allow"
        Action   = ["iam:CreateRole"]
        Resource = "arn:aws:iam::${var.account_id}:role/data-platform/runtime/${local.role_prefix}-*"
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = local.runtime_boundary_arn
          }
        }
      },
      {
        Sid    = "ManageRuntimeRoles"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy", "iam:DeleteRole", "iam:DeleteRolePolicy", "iam:DetachRolePolicy",
          "iam:GetRole", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
          "iam:ListRoleTags", "iam:PutRolePolicy", "iam:TagRole",
          "iam:UntagRole", "iam:UpdateAssumeRolePolicy", "iam:UpdateRole", "iam:UpdateRoleDescription",
        ]
        Resource = "arn:aws:iam::${var.account_id}:role/data-platform/runtime/${local.role_prefix}-*"
      },
      {
        Sid    = "ManageRuntimePolicies"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicy", "iam:DeletePolicyVersion",
          "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyTags", "iam:ListPolicyVersions",
          "iam:SetDefaultPolicyVersion", "iam:TagPolicy", "iam:UntagPolicy",
        ]
        Resource = "arn:aws:iam::${var.account_id}:policy/data-platform/runtime/${local.role_prefix}-*"
      },
      {
        Sid      = "ReadIAM"
        Effect   = "Allow"
        Action   = ["iam:Get*", "iam:List*"]
        Resource = "*"
      },
      {
        Sid      = "PassIngestRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [local.runtime_role_arns.ingest]
        Condition = {
          StringEquals = { "iam:PassedToService" = ["glue.amazonaws.com", "lambda.amazonaws.com"] }
        }
      },
      {
        Sid      = "PassTransformRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [local.runtime_role_arns.transform]
        Condition = {
          StringEquals = { "iam:PassedToService" = ["glue.amazonaws.com", "lambda.amazonaws.com"] }
        }
      },
      {
        Sid      = "PassOrchestrationRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [local.runtime_role_arns.orchestration]
        Condition = {
          StringEquals = { "iam:PassedToService" = ["states.amazonaws.com"] }
        }
      },
      {
        Sid      = "PassRedshiftRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [local.runtime_role_arns.redshift]
        Condition = {
          StringEquals = { "iam:PassedToService" = ["redshift-serverless.amazonaws.com"] }
        }
      },
      {
        Sid      = "ReadWritePlatformState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = [local.state_object_arn]
      },
      {
        Sid      = "LockPlatformState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.lock_object_arn]
      },
      {
        Sid      = "ListPlatformState"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [module.state_backend.bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = [local.state_key, "${local.state_key}.tflock"] }
        }
      },
      {
        Sid      = "EncryptPlatformState"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = [module.state_backend.kms_key_arn]
      },
      {
        Sid    = "ProtectBootstrapResources"
        Effect = "Deny"
        Action = [
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint", "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider", "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:DeleteRole",
          "iam:PutRolePermissionsBoundary", "iam:DeleteRolePermissionsBoundary",
        ]
        Resource = [
          "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com",
          "arn:aws:iam::${var.account_id}:role/bootstrap/jtrusty-data-platform-terraform-*",
          "arn:aws:iam::${var.account_id}:policy/bootstrap/jtrusty-data-platform-*-boundary-*",
        ]
      },
      {
        Sid    = "ProtectStateControls"
        Effect = "Deny"
        Action = [
          "kms:DisableKey", "kms:PutKeyPolicy", "kms:ScheduleKeyDeletion",
          "kms:TagResource", "kms:UntagResource",
        ]
        Resource = [module.state_backend.kms_key_arn]
      },
      {
        Sid    = "ProtectStateBucket"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket", "s3:DeleteBucketPolicy", "s3:PutBucketAcl", "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock", "s3:PutBucketVersioning", "s3:PutEncryptionConfiguration",
        ]
        Resource = [module.state_backend.bucket_arn]
      },
    ]
  })
}
