mock_provider "aws" {}

variables {
  aws_account_id           = "555044956444"
  environment              = "sandbox"
  resource_prefix          = "data-platform-sandbox"
  permissions_boundary_arn = "arn:aws:iam::555044956444:policy/bootstrap/jtrusty-data-platform-runtime-boundary-sandbox"

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "sandbox_uses_low_fixed_cost_defaults" {
  command = apply

  assert {
    condition     = toset(keys(module.platform_bucket)) == toset(["landing", "bronze", "silver", "artifacts", "athena-results", "config", "flow-logs"])
    error_message = "The foundation must create exactly five understandable storage boundaries, not a bucket per dataset."
  }

  assert {
    condition = alltrue([
      for purpose, bucket in module.platform_bucket :
      bucket.id == "data-platform-sandbox-${purpose}-555044956444"
    ])
    error_message = "Every platform bucket must be environment-qualified and globally unique without random naming."
  }

  assert {
    condition = (
      aws_dynamodb_table.metadata.name == "data-platform-sandbox-metadata" &&
      aws_dynamodb_table.metadata.billing_mode == "PROVISIONED" &&
      aws_dynamodb_table.metadata.read_capacity == 1 &&
      aws_dynamodb_table.metadata.write_capacity == 1 &&
      aws_dynamodb_table.metadata.hash_key == "namespace" &&
      aws_dynamodb_table.metadata.range_key == "key"
    )
    error_message = "The metadata table must default to the minimum 1/1 provisioned capacity and use a general platform metadata key."
  }

  assert {
    condition     = !one(aws_dynamodb_table.metadata.point_in_time_recovery).enabled
    error_message = "Sandbox PITR must default off to avoid recurring backup cost."
  }

  assert {
    condition     = !aws_dynamodb_table.metadata.deletion_protection_enabled
    error_message = "Sandbox metadata must remain disposable by default."
  }

  assert {
    condition = (
      one(aws_dynamodb_table.metadata.ttl).enabled &&
      one(aws_dynamodb_table.metadata.ttl).attribute_name == "expires_at"
    )
    error_message = "Metadata must support automatic expiry without a cleanup workload."
  }

  assert {
    condition     = one(aws_dynamodb_table.metadata.server_side_encryption).enabled
    error_message = "DynamoDB encryption must remain enabled with the AWS-owned key by default."
  }

  assert {
    condition = (
      toset(keys(aws_sqs_queue.work)) == toset(["ingest", "bronze-complete"]) &&
      toset(keys(aws_sqs_queue.dead_letter)) == toset(["ingest", "bronze-complete"]) &&
      toset(keys(aws_sqs_queue_policy.work)) == toset(["ingest", "bronze-complete"]) &&
      toset(keys(aws_sqs_queue_policy.dead_letter)) == toset(["ingest", "bronze-complete"])
    )
    error_message = "The foundation must create only the ingest and bronze-complete queues, each with a DLQ."
  }

  assert {
    condition = (
      alltrue([for queue in aws_sqs_queue.work : queue.sqs_managed_sse_enabled]) &&
      alltrue([for queue in aws_sqs_queue.dead_letter : queue.sqs_managed_sse_enabled])
    )
    error_message = "Queues must use no-additional-cost SQS-managed encryption."
  }

  assert {
    condition = alltrue([
      for name, queue in aws_sqs_queue.work :
      jsondecode(queue.redrive_policy).deadLetterTargetArn == aws_sqs_queue.dead_letter[name].arn &&
      jsondecode(queue.redrive_policy).maxReceiveCount == 5
    ])
    error_message = "Every work queue must depend on and redrive poison messages to its actual environment-local DLQ."
  }

  assert {
    condition = alltrue([
      for name, policy in aws_sqs_queue_redrive_allow_policy.dead_letter :
      jsondecode(policy.redrive_allow_policy).sourceQueueArns == [aws_sqs_queue.work[name].arn]
    ])
    error_message = "Every DLQ must explicitly allow redrive from its actual paired source queue."
  }

  assert {
    condition = (
      alltrue([
        for policy in aws_sqs_queue_policy.work : anytrue([
          for statement in jsondecode(policy.policy).Statement :
          statement.Effect == "Deny" &&
          statement.Principal == "*" &&
          statement.Action == "sqs:*" &&
          statement.Condition.Bool["aws:SecureTransport"] == "false"
        ])
      ]) &&
      alltrue([
        for policy in aws_sqs_queue_policy.dead_letter : anytrue([
          for statement in jsondecode(policy.policy).Statement :
          statement.Effect == "Deny" &&
          statement.Principal == "*" &&
          statement.Action == "sqs:*" &&
          statement.Condition.Bool["aws:SecureTransport"] == "false"
        ])
      ])
    )
    error_message = "Every queue policy must deny non-TLS access for every principal."
  }

  assert {
    condition     = length(aws_secretsmanager_secret.platform) == 0
    error_message = "Secret containers must be opt-in so an empty foundation has no Secrets Manager monthly charges."
  }

  assert {
    condition     = toset(keys(aws_iam_role.runtime)) == toset(["ingest", "transform", "orchestration", "redshift"])
    error_message = "The foundation must start with exactly four understandable runtime roles."
  }

  assert {
    condition = alltrue([
      for name, role in aws_iam_role.runtime :
      role.name == "data-platform-sandbox-${name}" &&
      role.path == "/data-platform/runtime/" &&
      role.permissions_boundary == var.permissions_boundary_arn
    ])
    error_message = "Every runtime role must remain visibly platform-scoped and use the Terraform-owned permissions boundary."
  }

  assert {
    condition = alltrue(flatten([
      for policy in aws_iam_role_policy.runtime : [
        for statement in jsondecode(policy.policy).Statement : alltrue([
          for action in flatten([statement.Action]) :
          action != "*" &&
          !startswith(lower(action), "iam:") &&
          lower(action) != "sts:assumerole"
        ])
      ]
    ]))
    error_message = "Runtime policies must not contain wildcard actions, IAM administration, PassRole, or role chaining."
  }

  assert {
    condition = alltrue(flatten([
      for policy in aws_iam_role_policy.runtime : [
        for statement in jsondecode(policy.policy).Statement : alltrue([
          for action in flatten([statement.Action]) :
          !(startswith(lower(action), "s3:") || lower(action) == "secretsmanager:getsecretvalue") ||
          alltrue([
            for resource in flatten([statement.Resource]) :
            resource != "*" && (
              startswith(resource, "arn:aws:s3:::data-platform-sandbox-") ||
              startswith(resource, "arn:aws:secretsmanager:us-east-2:555044956444:secret:data-platform/sandbox/")
            )
          ])
        ])
      ]
    ]))
    error_message = "Runtime S3 and secret data access must be resource-scoped to this environment's platform boundary."
  }

  assert {
    condition = alltrue([
      for role in aws_iam_role.runtime :
      alltrue([
        for statement in jsondecode(role.assume_role_policy).Statement :
        statement.Effect == "Allow" &&
        try(statement.Principal.Service, null) != null &&
        alltrue([
          for service in flatten([statement.Principal.Service]) :
          contains(["lambda.amazonaws.com", "glue.amazonaws.com", "states.amazonaws.com", "redshift-serverless.amazonaws.com", "redshift.amazonaws.com"], service)
        ]) &&
        try(statement.Principal.AWS, null) == null &&
        try(statement.Principal.Federated, null) == null
      ])
    ])
    error_message = "Runtime trust policies must trust only the intended AWS services, never human, federated, or arbitrary AWS principals."
  }

  assert {
    condition = toset(flatten([
      for statement in jsondecode(aws_iam_role.runtime["redshift"].assume_role_policy).Statement :
      flatten([statement.Principal.Service])
    ])) == toset(["redshift.amazonaws.com", "redshift-serverless.amazonaws.com"])
    error_message = "The Redshift data-access role must trust both exact Redshift service principals."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_role.runtime["redshift"].assume_role_policy).Statement :
      statement.Condition.StringEquals["aws:SourceAccount"] == "555044956444"
    ])
    error_message = "The Redshift trust must reject confused-deputy requests from other AWS accounts."
  }

  assert {
    condition = alltrue([
      for role_name in ["transform", "orchestration"] : anytrue([
        for statement in jsondecode(aws_iam_role_policy.runtime[role_name].policy).Statement :
        contains(flatten([statement.Action]), "s3:PutObject") &&
        contains(flatten([statement.Resource]), "arn:aws:s3:::data-platform-sandbox-athena-results-555044956444/*")
      ])
    ])
    error_message = "Every runtime role that starts Athena queries must be able to write the exact query-results bucket."
  }

  assert {
    condition = alltrue([
      for role_name in ["ingest", "transform"] : anytrue([
        for statement in jsondecode(aws_iam_role_policy.runtime[role_name].policy).Statement :
        contains(flatten([statement.Action]), "s3:GetObject") &&
        contains(flatten([statement.Resource]), "arn:aws:s3:::data-platform-sandbox-artifacts-555044956444/*")
      ])
    ])
    error_message = "Every Glue-capable runtime role must be able to read its scripts from the artifacts bucket."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.runtime["transform"].policy).Statement :
      contains(flatten([statement.Action]), "sqs:ReceiveMessage") &&
      contains(flatten([statement.Resource]), "arn:aws:sqs:us-east-2:555044956444:data-platform-sandbox-bronze-complete")
    ])
    error_message = "The transformation role must consume the Bronze-complete queue published by ingestion."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.runtime["transform"].policy).Statement :
      contains(flatten([statement.Action]), "athena:GetDataCatalog") &&
      contains(flatten([statement.Resource]), "arn:aws:athena:us-east-2:555044956444:datacatalog/AwsDataCatalog")
    ])
    error_message = "Transformation queries must be able to use Athena's default Glue data catalog."
  }

  assert {
    condition = (
      anytrue([
        for statement in jsondecode(aws_iam_role_policy.runtime["orchestration"].policy).Statement :
        contains(flatten([statement.Action]), "redshift-data:ExecuteStatement") &&
        contains(flatten([statement.Resource]), "arn:aws:redshift-serverless:us-east-2:555044956444:workgroup/*")
      ]) &&
      anytrue([
        for statement in jsondecode(aws_iam_role_policy.runtime["orchestration"].policy).Statement :
        contains(flatten([statement.Action]), "redshift-data:GetStatementResult") &&
        statement.Resource == "*" &&
        statement.Condition.StringEquals["redshift-data:statement-owner-iam-userid"] == "$${aws:userid}"
      ])
    )
    error_message = "Redshift Data API execution must target tagged workgroups and statement reads must be owner-restricted."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_role_policy.runtime["orchestration"].policy).Statement :
      !contains(flatten([statement.Resource]), "arn:aws:s3:::data-platform-sandbox-bronze-555044956444/*") ||
      !contains(flatten([statement.Action]), "s3:PutObject")
    ])
    error_message = "Orchestration must not write immutable Bronze history."
  }
}

run "dynamodb_capacity_is_configurable" {
  command = apply

  variables {
    metadata_read_capacity  = 2
    metadata_write_capacity = 3
  }

  assert {
    condition = (
      aws_dynamodb_table.metadata.billing_mode == "PROVISIONED" &&
      aws_dynamodb_table.metadata.read_capacity == 2 &&
      aws_dynamodb_table.metadata.write_capacity == 3
    )
    error_message = "Operators must be able to select explicitly sized provisioned metadata capacity through tfvars."
  }
}

run "reject_zero_dynamodb_capacity" {
  command = plan

  variables {
    metadata_read_capacity = 0
  }

  expect_failures = [var.metadata_read_capacity]
}

run "secret_containers_are_namespaced_and_value_free" {
  command = apply

  variables {
    secret_names = ["sources/vendor-a", "warehouse/redshift-admin"]
  }

  assert {
    condition = (
      aws_secretsmanager_secret.platform["sources/vendor-a"].name == "data-platform/sandbox/sources/vendor-a" &&
      aws_secretsmanager_secret.platform["warehouse/redshift-admin"].name == "data-platform/sandbox/warehouse/redshift-admin"
    )
    error_message = "Opt-in secret containers must remain inside the environment-specific data-platform namespace."
  }

}

run "production_enables_recovery_and_deletion_guards" {
  command = apply

  variables {
    aws_account_id                     = "991278600180"
    environment                        = "production"
    resource_prefix                    = "data-platform-production"
    permissions_boundary_arn           = "arn:aws:iam::991278600180:policy/bootstrap/jtrusty-data-platform-runtime-boundary-production"
    force_destroy_buckets              = false
    metadata_point_in_time_recovery    = true
    metadata_deletion_protection       = true
    noncurrent_version_expiration_days = 90
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Owner       = "data-platform"
      Platform    = "data-platform"
    }
  }

  assert {
    condition     = one(aws_dynamodb_table.metadata.point_in_time_recovery).enabled
    error_message = "Production metadata must enable point-in-time recovery."
  }

  assert {
    condition     = aws_dynamodb_table.metadata.deletion_protection_enabled
    error_message = "Production metadata must enable deletion protection."
  }
}

run "reject_unsafe_production_bucket_deletion" {
  command = plan

  variables {
    aws_account_id                  = "991278600180"
    environment                     = "production"
    resource_prefix                 = "data-platform-production"
    permissions_boundary_arn        = "arn:aws:iam::991278600180:policy/bootstrap/jtrusty-data-platform-runtime-boundary-production"
    force_destroy_buckets           = true
    metadata_point_in_time_recovery = true
    metadata_deletion_protection    = true
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Owner       = "data-platform"
      Platform    = "data-platform"
    }
  }

  expect_failures = [var.force_destroy_buckets]
}

run "reject_production_without_metadata_recovery" {
  command = plan

  variables {
    aws_account_id                  = "991278600180"
    environment                     = "production"
    resource_prefix                 = "data-platform-production"
    permissions_boundary_arn        = "arn:aws:iam::991278600180:policy/bootstrap/jtrusty-data-platform-runtime-boundary-production"
    force_destroy_buckets           = false
    metadata_point_in_time_recovery = false
    metadata_deletion_protection    = true
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Owner       = "data-platform"
      Platform    = "data-platform"
    }
  }

  expect_failures = [var.metadata_point_in_time_recovery]
}

run "reject_production_without_metadata_deletion_protection" {
  command = plan

  variables {
    aws_account_id                  = "991278600180"
    environment                     = "production"
    resource_prefix                 = "data-platform-production"
    permissions_boundary_arn        = "arn:aws:iam::991278600180:policy/bootstrap/jtrusty-data-platform-runtime-boundary-production"
    force_destroy_buckets           = false
    metadata_point_in_time_recovery = true
    metadata_deletion_protection    = false
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Owner       = "data-platform"
      Platform    = "data-platform"
    }
  }

  expect_failures = [var.metadata_deletion_protection]
}

run "reject_secret_path_escape" {
  command = plan

  variables {
    secret_names = ["../unrelated-secret"]
  }

  expect_failures = [var.secret_names]
}
