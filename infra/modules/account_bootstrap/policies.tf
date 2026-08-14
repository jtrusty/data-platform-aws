locals {
  # Global endpoints do not populate aws:RequestedRegion, so denying on that key
  # must exempt them or every IAM and STS call fails.
  global_service_not_actions = [
    "account:*",
    "iam:*",
    "organizations:*",
    "s3:GetAccountPublicAccessBlock",
    "s3:ListAllMyBuckets",
    "sts:*",
    "support:*",
  ]

  region_guardrail_statement = {
    Sid       = "DenyOutsideApprovedRegion"
    Effect    = "Deny"
    NotAction = local.global_service_not_actions
    Resource  = "*"
    Condition = {
      StringNotEquals = {
        "aws:RequestedRegion" = "us-east-2"
      }
    }
  }

  # Human sessions also need the console's global identity endpoints.
  human_region_guardrail_statement = {
    Sid       = "DenyOutsideApprovedRegion"
    Effect    = "Deny"
    NotAction = concat(local.global_service_not_actions, ["identitystore:*", "sso:*", "sso-directory:*"])
    Resource  = "*"
    Condition = {
      StringNotEquals = {
        "aws:RequestedRegion" = "us-east-2"
      }
    }
  }

  # Every resource below bills by the hour or the month whether or not the
  # platform uses it. Terraform never needs them, so the credential cannot
  # create them even if a plan or a console operator asks for it.
  network_cost_guardrail_statements = [
    {
      Sid    = "DenyBilledNetworkAndComputeResources"
      Effect = "Deny"
      Action = [
        "ec2:Accept*Attachment",
        "ec2:Accept*Peering*",
        "ec2:AllocateAddress",
        "ec2:AssociateAddress",
        "ec2:AttachInternetGateway",
        "ec2:Create*Gateway*",
        "ec2:Create*Peering*",
        "ec2:CreateClientVpnEndpoint",
        "ec2:CreateVolume",
        "ec2:CreateVpnConnection",
        "ec2:RunInstances",
      ]
      Resource = "*"
    },
    {
      Sid      = "DenyBilledInterfaceEndpoints"
      Effect   = "Deny"
      Action   = ["ec2:CreateVpcEndpoint"]
      Resource = "*"
      # Only an explicitly billed endpoint type is denied, so the free S3
      # gateway endpoint keeps working even where the key is absent.
      Condition = {
        StringEquals = {
          "ec2:VpcEndpointType" = ["Interface", "GatewayLoadBalancer"]
        }
      }
    },
  ]

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

  # The guardrail denies live in their own attached policy rather than in the
  # boundary: an explicit Deny anywhere applies, and the boundary has to stay
  # inside the 6,144-character managed-policy quota.
  deployment_guardrail_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = concat([local.region_guardrail_statement], local.network_cost_guardrail_statements)
  })

  terraform_deployment_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.terraform_deployment_statements
  })

  terraform_deployment_statements = [
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
}
