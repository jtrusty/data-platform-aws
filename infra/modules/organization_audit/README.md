<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_budgets_budget.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_cloudtrail.organization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_config_configuration_recorder.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder) | resource |
| [aws_config_configuration_recorder_status.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status) | resource |
| [aws_config_delivery_channel.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_delivery_channel) | resource |
| [aws_guardduty_detector.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector) | resource |
| [aws_iam_service_linked_role.detection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_s3_bucket.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_securityhub_account.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_account) | resource |
| [aws_securityhub_standards_subscription.foundational](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_standards_subscription) | resource |
| [aws_sns_topic.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.alert_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_organizations_organization.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_email"></a> [alert\_email](#input\_alert\_email) | Address subscribed to management-account budget alerts. Supplied out of band; never committed. | `string` | `null` | no |
| <a name="input_config_resource_types"></a> [config\_resource\_types](#input\_config\_resource\_types) | Resource types AWS Config records in the management account. | `set(string)` | <pre>[<br/>  "AWS::CloudTrail::Trail",<br/>  "AWS::IAM::Policy",<br/>  "AWS::IAM::Role",<br/>  "AWS::KMS::Key",<br/>  "AWS::S3::Bucket"<br/>]</pre> | no |
| <a name="input_enable_security_hub"></a> [enable\_security\_hub](#input\_enable\_security\_hub) | Enable Security Hub with the foundational standard in the management account. Off by default because it is billed per control check. | `bool` | `false` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days to retain organization CloudTrail objects; storage is the only recurring cost of this trail. | `number` | `365` | no |
| <a name="input_manage_detective_service_linked_roles"></a> [manage\_detective\_service\_linked\_roles](#input\_manage\_detective\_service\_linked\_roles) | Create the management account's Config, GuardDuty, and Security Hub service-linked roles. | `bool` | `true` | no |
| <a name="input_management_account_id"></a> [management\_account\_id](#input\_management\_account\_id) | Organizations management account that owns the organization trail. | `string` | `"699599381258"` | no |
| <a name="input_monthly_budget_usd"></a> [monthly\_budget\_usd](#input\_monthly\_budget\_usd) | Monthly cost budget for the management account. | `number` | `25` | no |
| <a name="input_noncurrent_version_expiration_days"></a> [noncurrent\_version\_expiration\_days](#input\_noncurrent\_version\_expiration\_days) | Days to retain overwritten or deleted audit-log versions. | `number` | `30` | no |
| <a name="input_state_bucket_data_events"></a> [state\_bucket\_data\_events](#input\_state\_bucket\_data\_events) | Terraform state bucket ARNs to record S3 object-level data events for; billed per event, empty by default. | `set(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory organization audit tags. | `map(string)` | n/a | yes |
| <a name="input_trail_name"></a> [trail\_name](#input\_trail\_name) | Organization CloudTrail name. | `string` | `"jtrusty-data-platform-organization"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alert_topic_arn"></a> [alert\_topic\_arn](#output\_alert\_topic\_arn) | SNS topic receiving management-account budget alerts. |
| <a name="output_audit_bucket_name"></a> [audit\_bucket\_name](#output\_audit\_bucket\_name) | Organization audit log bucket name. |
| <a name="output_guardduty_detector_id"></a> [guardduty\_detector\_id](#output\_guardduty\_detector\_id) | GuardDuty detector protecting the management account. |
| <a name="output_log_retention_days"></a> [log\_retention\_days](#output\_log\_retention\_days) | Days audit objects are retained before expiration. |
| <a name="output_monthly_budget_usd"></a> [monthly\_budget\_usd](#output\_monthly\_budget\_usd) | Management-account monthly cost budget in USD. |
| <a name="output_security_hub_enabled"></a> [security\_hub\_enabled](#output\_security\_hub\_enabled) | Whether Security Hub is enabled in the management account. |
| <a name="output_trail_arn"></a> [trail\_arn](#output\_trail\_arn) | Organization CloudTrail ARN. |
| <a name="output_trail_name"></a> [trail\_name](#output\_trail\_name) | Organization CloudTrail name. |
<!-- END_TF_DOCS -->