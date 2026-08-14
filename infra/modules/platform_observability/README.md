<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15.0, < 2.0.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.4, < 3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_budgets_budget.account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_cloudwatch_log_group.athena_spend_guard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.athena_scanned_bytes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.dead_letter_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_lambda_function.athena_spend_guard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.athena_spend_guard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sns_topic.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.alert_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.athena_spend_guard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [archive_file.athena_spend_guard](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_email"></a> [alert\_email](#input\_alert\_email) | Address subscribed to platform alerts. Never committed; supplied through a gitignored tfvars file locally and a GitHub Environment secret in CI. | `string` | `null` | no |
| <a name="input_athena_monthly_bytes_limit"></a> [athena\_monthly\_bytes\_limit](#input\_athena\_monthly\_bytes\_limit) | Month-to-date scanned bytes after which the Athena workgroup is disabled. 200 GiB is about $1 of scan at the current $5/TB rate. | `number` | `214748364800` | no |
| <a name="input_athena_workgroup_name"></a> [athena\_workgroup\_name](#input\_athena\_workgroup\_name) | Athena workgroup whose monthly scanned bytes are capped. | `string` | n/a | yes |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account that owns the alerting and spend controls. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region containing the alarms and alert topic. | `string` | `"us-east-2"` | no |
| <a name="input_dead_letter_queue_names"></a> [dead\_letter\_queue\_names](#input\_dead\_letter\_queue\_names) | Dead-letter queues alarmed when any message arrives. | `set(string)` | `[]` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment identity used in every alerting resource name. | `string` | n/a | yes |
| <a name="input_guard_role_arn"></a> [guard\_role\_arn](#input\_guard\_role\_arn) | Bootstrap-owned execution role for the Athena spend guard. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Finite CloudWatch retention for the spend guard's own logs. | `number` | `14` | no |
| <a name="input_monthly_budget_usd"></a> [monthly\_budget\_usd](#input\_monthly\_budget\_usd) | Monthly cost budget for this account. Notification only; AWS Budgets does not stop spend. | `number` | `25` | no |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | Environment-qualified data platform resource prefix. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory data-platform boundary tags. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alarm_names"></a> [alarm\_names](#output\_alarm\_names) | CloudWatch alarms publishing to the platform alert topic. |
| <a name="output_alert_email_subscribed"></a> [alert\_email\_subscribed](#output\_alert\_email\_subscribed) | Whether an email subscription was created for platform alerts. Only the fact is published, never the address. |
| <a name="output_alert_topic_arn"></a> [alert\_topic\_arn](#output\_alert\_topic\_arn) | SNS topic receiving budget notifications and platform alarms. |
| <a name="output_athena_monthly_bytes_limit"></a> [athena\_monthly\_bytes\_limit](#output\_athena\_monthly\_bytes\_limit) | Month-to-date Athena scanned bytes that disable the workgroup. |
| <a name="output_athena_spend_guard_function_name"></a> [athena\_spend\_guard\_function\_name](#output\_athena\_spend\_guard\_function\_name) | Lambda function that enforces the Athena monthly limit. |
| <a name="output_budget_name"></a> [budget\_name](#output\_budget\_name) | Monthly account cost budget name. |
| <a name="output_monthly_budget_usd"></a> [monthly\_budget\_usd](#output\_monthly\_budget\_usd) | Monthly account cost budget in USD. |
<!-- END_TF_DOCS -->