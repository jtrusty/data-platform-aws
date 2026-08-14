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
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Globally unique name for the platform bucket. | `string` | n/a | yes |
| <a name="input_current_expiration"></a> [current\_expiration](#input\_current\_expiration) | Optional number of days after which current objects expire. Null retains current objects. | `number` | `null` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow Terraform to delete a non-empty bucket. Keep false outside disposable tests. | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Optional ARN of the platform KMS key. Null uses no-additional-cost SSE-S3 encryption. | `string` | `null` | no |
| <a name="input_log_delivery"></a> [log\_delivery](#input\_log\_delivery) | Optional AWS log-delivery grant. AWS Config and VPC flow logs write with the service's own credentials, so the bucket policy must name the service principal and the owning account. | <pre>object({<br/>    account_id        = string<br/>    service_principal = string<br/>    prefix            = optional(string, "")<br/>  })</pre> | `null` | no |
| <a name="input_noncurrent_expiration"></a> [noncurrent\_expiration](#input\_noncurrent\_expiration) | Days to retain noncurrent object versions. | `number` | `90` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. The platform boundary tags are mandatory. | `map(string)` | n/a | yes |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Enable object versioning where recovery needs justify the additional storage. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the bucket. |
| <a name="output_id"></a> [id](#output\_id) | Name of the bucket. |
<!-- END_TF_DOCS -->