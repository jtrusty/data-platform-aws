<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_platform_bucket"></a> [platform\_bucket](#module\_platform\_bucket) | ../secure_bucket | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_role.runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_secretsmanager_secret.platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_sqs_queue.dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.work](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.work](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_redrive_allow_policy.dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_artifact_expiration_days"></a> [artifact\_expiration\_days](#input\_artifact\_expiration\_days) | Days to retain current deployment artifacts. | `number` | `30` | no |
| <a name="input_athena_results_expiration_days"></a> [athena\_results\_expiration\_days](#input\_athena\_results\_expiration\_days) | Days to retain reproducible Athena query results. | `number` | `7` | no |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account that owns the environment foundation. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region containing the environment foundation. | `string` | `"us-east-2"` | no |
| <a name="input_dlq_message_retention_seconds"></a> [dlq\_message\_retention\_seconds](#input\_dlq\_message\_retention\_seconds) | Retention period for failed messages in dead-letter queues. | `number` | `1209600` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment identity used in every platform resource name. | `string` | n/a | yes |
| <a name="input_force_destroy_buckets"></a> [force\_destroy\_buckets](#input\_force\_destroy\_buckets) | Allow deletion of non-empty buckets in the disposable sandbox only. | `bool` | `false` | no |
| <a name="input_landing_expiration_days"></a> [landing\_expiration\_days](#input\_landing\_expiration\_days) | Days to retain temporary landing objects. | `number` | `7` | no |
| <a name="input_metadata_deletion_protection"></a> [metadata\_deletion\_protection](#input\_metadata\_deletion\_protection) | Enable DynamoDB deletion protection; required in production. | `bool` | `false` | no |
| <a name="input_metadata_point_in_time_recovery"></a> [metadata\_point\_in\_time\_recovery](#input\_metadata\_point\_in\_time\_recovery) | Enable DynamoDB point-in-time recovery; required in production. | `bool` | `false` | no |
| <a name="input_metadata_read_capacity"></a> [metadata\_read\_capacity](#input\_metadata\_read\_capacity) | Provisioned metadata table read capacity units. | `number` | `1` | no |
| <a name="input_metadata_write_capacity"></a> [metadata\_write\_capacity](#input\_metadata\_write\_capacity) | Provisioned metadata table write capacity units. | `number` | `1` | no |
| <a name="input_noncurrent_version_expiration_days"></a> [noncurrent\_version\_expiration\_days](#input\_noncurrent\_version\_expiration\_days) | Days to retain noncurrent object versions in versioned buckets. | `number` | `7` | no |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | Terraform-owned maximum-permissions policy applied to every runtime role. | `string` | n/a | yes |
| <a name="input_queue_max_receive_count"></a> [queue\_max\_receive\_count](#input\_queue\_max\_receive\_count) | Failed receives allowed before a message is sent to its DLQ. | `number` | `5` | no |
| <a name="input_queue_message_retention_seconds"></a> [queue\_message\_retention\_seconds](#input\_queue\_message\_retention\_seconds) | Retention period for work queue messages. | `number` | `345600` | no |
| <a name="input_queue_visibility_timeout_seconds"></a> [queue\_visibility\_timeout\_seconds](#input\_queue\_visibility\_timeout\_seconds) | Time a received work message remains hidden from other consumers. | `number` | `300` | no |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | Environment-qualified data platform resource prefix. | `string` | n/a | yes |
| <a name="input_secret_names"></a> [secret\_names](#input\_secret\_names) | Opt-in secret container suffixes; Terraform never accepts or writes secret values. | `set(string)` | `[]` | no |
| <a name="input_secret_namespace"></a> [secret\_namespace](#input\_secret\_namespace) | Optional environment-qualified Secrets Manager namespace. | `string` | `null` | no |
| <a name="input_secret_recovery_window_days"></a> [secret\_recovery\_window\_days](#input\_secret\_recovery\_window\_days) | Secrets Manager deletion recovery window; use zero only for disposable environments. | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory data-platform boundary tags. | `map(string)` | n/a | yes |
| <a name="input_versioned_bucket_purposes"></a> [versioned\_bucket\_purposes](#input\_versioned\_bucket\_purposes) | Bucket purposes that retain overwritten and deleted object versions. | `set(string)` | <pre>[<br/>  "bronze",<br/>  "artifacts"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Platform bucket ARNs keyed by storage purpose. |
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | Platform bucket names keyed by storage purpose. |
| <a name="output_dead_letter_queue_arns"></a> [dead\_letter\_queue\_arns](#output\_dead\_letter\_queue\_arns) | Dead-letter queue ARNs keyed by workflow boundary. |
| <a name="output_dead_letter_queue_urls"></a> [dead\_letter\_queue\_urls](#output\_dead\_letter\_queue\_urls) | Dead-letter queue URLs keyed by workflow boundary. |
| <a name="output_metadata_table_arn"></a> [metadata\_table\_arn](#output\_metadata\_table\_arn) | Platform metadata and watermark table ARN. |
| <a name="output_metadata_table_name"></a> [metadata\_table\_name](#output\_metadata\_table\_name) | Platform metadata and watermark table name. |
| <a name="output_queue_arns"></a> [queue\_arns](#output\_queue\_arns) | Work queue ARNs keyed by workflow boundary. |
| <a name="output_queue_urls"></a> [queue\_urls](#output\_queue\_urls) | Work queue URLs keyed by workflow boundary. |
| <a name="output_runtime_role_arns"></a> [runtime\_role\_arns](#output\_runtime\_role\_arns) | Runtime role ARNs keyed by responsibility. |
| <a name="output_secret_arns"></a> [secret\_arns](#output\_secret\_arns) | Opt-in secret container ARNs keyed by their namespace-relative names. |
<!-- END_TF_DOCS -->