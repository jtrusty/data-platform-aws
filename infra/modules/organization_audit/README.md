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
| [aws_cloudtrail.organization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_s3_bucket.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_organizations_organization.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days to retain organization CloudTrail objects; storage is the only recurring cost of this trail. | `number` | `365` | no |
| <a name="input_management_account_id"></a> [management\_account\_id](#input\_management\_account\_id) | Organizations management account that owns the organization trail. | `string` | `"699599381258"` | no |
| <a name="input_noncurrent_version_expiration_days"></a> [noncurrent\_version\_expiration\_days](#input\_noncurrent\_version\_expiration\_days) | Days to retain overwritten or deleted audit-log versions. | `number` | `30` | no |
| <a name="input_state_bucket_data_events"></a> [state\_bucket\_data\_events](#input\_state\_bucket\_data\_events) | Terraform state bucket ARNs to record S3 object-level data events for; billed per event, empty by default. | `set(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory organization audit tags. | `map(string)` | n/a | yes |
| <a name="input_trail_name"></a> [trail\_name](#input\_trail\_name) | Organization CloudTrail name. | `string` | `"jtrusty-data-platform-organization"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_audit_bucket_name"></a> [audit\_bucket\_name](#output\_audit\_bucket\_name) | Organization audit log bucket name. |
| <a name="output_log_retention_days"></a> [log\_retention\_days](#output\_log\_retention\_days) | Days audit objects are retained before expiration. |
| <a name="output_trail_arn"></a> [trail\_arn](#output\_trail\_arn) | Organization CloudTrail ARN. |
| <a name="output_trail_name"></a> [trail\_name](#output\_trail\_name) | Organization CloudTrail name. |
<!-- END_TF_DOCS -->