locals {
  query_editor_non_resource_actions = [
    "sqlworkbench:BatchDeleteFolder",
    "sqlworkbench:CreateFolder",
    "sqlworkbench:DeleteTab",
    "sqlworkbench:DriverExecute",
    "sqlworkbench:GenerateSession",
    "sqlworkbench:GetAccountInfo",
    "sqlworkbench:GetAccountSettings",
    "sqlworkbench:GetAutocompletionMetadata",
    "sqlworkbench:GetAutocompletionResource",
    "sqlworkbench:GetQueryExecutionHistory",
    "sqlworkbench:GetSchemaInference",
    "sqlworkbench:GetUserInfo",
    "sqlworkbench:GetUserWorkspaceSettings",
    "sqlworkbench:ListConnections",
    "sqlworkbench:ListFiles",
    "sqlworkbench:ListNotebooks",
    "sqlworkbench:ListQueryExecutionHistory",
    "sqlworkbench:ListRedshiftClusters",
    "sqlworkbench:ListTabs",
    "sqlworkbench:ListTaggedResources",
    "sqlworkbench:PutTab",
    "sqlworkbench:PutUserWorkspaceSettings",
    "sqlworkbench:UpdateFolder",
  ]

  query_editor_create_actions = [
    "sqlworkbench:CreateChart",
    "sqlworkbench:CreateConnection",
    "sqlworkbench:CreateNotebook",
    "sqlworkbench:CreateNotebookFromVersion",
    "sqlworkbench:CreateSavedQuery",
    "sqlworkbench:DuplicateNotebook",
    "sqlworkbench:ImportNotebook",
  ]

  query_editor_owned_actions = [
    "sqlworkbench:AssociateConnectionWithChart",
    "sqlworkbench:AssociateConnectionWithTab",
    "sqlworkbench:AssociateNotebookWithTab",
    "sqlworkbench:AssociateQueryWithTab",
    "sqlworkbench:BatchGetNotebookCell",
    "sqlworkbench:CreateNotebookCell",
    "sqlworkbench:CreateNotebookFromVersion",
    "sqlworkbench:CreateNotebookVersion",
    "sqlworkbench:DeleteChart",
    "sqlworkbench:DeleteConnection",
    "sqlworkbench:DeleteNotebook",
    "sqlworkbench:DeleteNotebookCell",
    "sqlworkbench:DeleteNotebookVersion",
    "sqlworkbench:DeleteSavedQuery",
    "sqlworkbench:DuplicateNotebook",
    "sqlworkbench:ExportNotebook",
    "sqlworkbench:GetChart",
    "sqlworkbench:GetConnection",
    "sqlworkbench:GetNotebook",
    "sqlworkbench:GetNotebookVersion",
    "sqlworkbench:GetSavedQuery",
    "sqlworkbench:ImportNotebook",
    "sqlworkbench:ListNotebookVersions",
    "sqlworkbench:ListSavedQueryVersions",
    "sqlworkbench:ListTagsForResource",
    "sqlworkbench:RestoreNotebookVersion",
    "sqlworkbench:UpdateChart",
    "sqlworkbench:UpdateConnection",
    "sqlworkbench:UpdateFileFolder",
    "sqlworkbench:UpdateNotebook",
    "sqlworkbench:UpdateNotebookCellContent",
    "sqlworkbench:UpdateNotebookCellLayout",
    "sqlworkbench:UpdateSavedQuery",
  ]
}

resource "aws_iam_policy" "query_editor" {
  name        = "jtrusty-data-platform-query-editor-v2"
  path        = "/data-platform/human/"
  description = "Owner-only Query Editor v2 workspace access without password-secret management"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "QueryEditorNonResourceActions"
        Effect   = "Allow"
        Action   = local.query_editor_non_resource_actions
        Resource = "*"
      },
      {
        Sid      = "CreateOwnedQueryEditorResources"
        Effect   = "Allow"
        Action   = local.query_editor_create_actions
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/sqlworkbench-resource-owner" = "$${aws:userid}"
          }
        }
      },
      {
        Sid      = "OperateOwnedQueryEditorResources"
        Effect   = "Allow"
        Action   = local.query_editor_owned_actions
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/sqlworkbench-resource-owner" = "$${aws:userid}"
          }
        }
      },
      {
        Sid      = "TagOnlyAsOwner"
        Effect   = "Allow"
        Action   = "sqlworkbench:TagResource"
        Resource = "*"
        Condition = {
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = "sqlworkbench-resource-owner"
          }
          StringEquals = {
            "aws:RequestTag/sqlworkbench-resource-owner"  = "$${aws:userid}"
            "aws:ResourceTag/sqlworkbench-resource-owner" = "$${aws:userid}"
          }
        }
      },
      {
        Sid      = "DiscoverTagsThroughQueryEditor"
        Effect   = "Allow"
        Action   = "tag:GetResources"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:CalledViaLast" = "sqlworkbench.amazonaws.com"
          }
        }
      },
    ]
  })
  tags = var.tags
}
