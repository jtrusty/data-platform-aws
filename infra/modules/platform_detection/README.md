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
| [aws_config_configuration_recorder.platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder) | resource |
| [aws_config_configuration_recorder_status.platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status) | resource |
| [aws_config_delivery_channel.platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_delivery_channel) | resource |
| [aws_flow_log.analytics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_guardduty_detector.platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector) | resource |
| [aws_securityhub_account.platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_account) | resource |
| [aws_securityhub_standards_subscription.foundational](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_standards_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account the detective controls protect. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region the detective controls run in. | `string` | `"us-east-2"` | no |
| <a name="input_config_bucket_id"></a> [config\_bucket\_id](#input\_config\_bucket\_id) | Bucket receiving AWS Config configuration snapshots and history. | `string` | n/a | yes |
| <a name="input_config_recorder_role_arn"></a> [config\_recorder\_role\_arn](#input\_config\_recorder\_role\_arn) | AWS Config service-linked role created by the account bootstrap. | `string` | n/a | yes |
| <a name="input_config_resource_types"></a> [config\_resource\_types](#input\_config\_resource\_types) | Resource types AWS Config records. | `set(string)` | <pre>[<br/>  "AWS::CloudTrail::Trail",<br/>  "AWS::DynamoDB::Table",<br/>  "AWS::EC2::SecurityGroup",<br/>  "AWS::EC2::Subnet",<br/>  "AWS::EC2::VPC",<br/>  "AWS::IAM::Policy",<br/>  "AWS::IAM::Role",<br/>  "AWS::KMS::Key",<br/>  "AWS::Lambda::Function",<br/>  "AWS::S3::Bucket",<br/>  "AWS::SQS::Queue"<br/>]</pre> | no |
| <a name="input_enable_security_hub"></a> [enable\_security\_hub](#input\_enable\_security\_hub) | Enable Security Hub with the AWS Foundational Security Best Practices standard. Off by default: it is billed per control check and is the most expensive control in this module. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment identity used in detective resource names. | `string` | n/a | yes |
| <a name="input_flow_log_bucket_arn"></a> [flow\_log\_bucket\_arn](#input\_flow\_log\_bucket\_arn) | Bucket ARN receiving VPC flow log records. | `string` | n/a | yes |
| <a name="input_flow_log_traffic_type"></a> [flow\_log\_traffic\_type](#input\_flow\_log\_traffic\_type) | Traffic recorded by VPC flow logs. | `string` | `"ALL"` | no |
| <a name="input_guardduty_publishing_frequency"></a> [guardduty\_publishing\_frequency](#input\_guardduty\_publishing\_frequency) | How often GuardDuty publishes updated findings to downstream targets. | `string` | `"SIX_HOURS"` | no |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | Environment-qualified data platform resource prefix. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory data-platform boundary tags. | `map(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Analytics VPC whose traffic is recorded. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_recorder_name"></a> [config\_recorder\_name](#output\_config\_recorder\_name) | AWS Config configuration recorder name. |
| <a name="output_config_resource_types"></a> [config\_resource\_types](#output\_config\_resource\_types) | Resource types AWS Config records; a bounded list keeps configuration-item charges predictable. |
| <a name="output_flow_log_id"></a> [flow\_log\_id](#output\_flow\_log\_id) | VPC flow log recording analytics network traffic. |
| <a name="output_guardduty_detector_id"></a> [guardduty\_detector\_id](#output\_guardduty\_detector\_id) | GuardDuty detector protecting this account. |
| <a name="output_security_hub_enabled"></a> [security\_hub\_enabled](#output\_security\_hub\_enabled) | Whether Security Hub and the foundational standard are enabled. |
<!-- END_TF_DOCS -->