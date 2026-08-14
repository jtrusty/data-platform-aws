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
| [aws_athena_workgroup.analytics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_workgroup) | resource |
| [aws_glue_catalog_database.layer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_athena_results_bucket_id"></a> [athena\_results\_bucket\_id](#input\_athena\_results\_bucket\_id) | Exact platform bucket used for Athena query results. | `string` | n/a | yes |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account that owns the Athena workgroup and result bucket. | `string` | n/a | yes |
| <a name="input_bronze_bucket_id"></a> [bronze\_bucket\_id](#input\_bronze\_bucket\_id) | Exact platform Bronze bucket represented by the baseline catalog database. | `string` | n/a | yes |
| <a name="input_bytes_scanned_cutoff_per_query"></a> [bytes\_scanned\_cutoff\_per\_query](#input\_bytes\_scanned\_cutoff\_per\_query) | Hard maximum bytes scanned by one Athena query; 10 GiB costs about five cents at the current standard rate. | `number` | `10737418240` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment identity used in every analytics resource name. | `string` | n/a | yes |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | Environment-qualified data platform resource prefix. | `string` | n/a | yes |
| <a name="input_silver_bucket_id"></a> [silver\_bucket\_id](#input\_silver\_bucket\_id) | Exact platform Silver bucket represented by the baseline catalog database. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory data-platform boundary tags. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bytes_scanned_cutoff_per_query"></a> [bytes\_scanned\_cutoff\_per\_query](#output\_bytes\_scanned\_cutoff\_per\_query) | Hard per-query Athena scan limit in bytes. |
| <a name="output_catalog_database_names"></a> [catalog\_database\_names](#output\_catalog\_database\_names) | Glue Catalog database names keyed by lake layer. |
| <a name="output_workgroup_arn"></a> [workgroup\_arn](#output\_workgroup\_arn) | Cost-controlled Athena workgroup ARN. |
| <a name="output_workgroup_name"></a> [workgroup\_name](#output\_workgroup\_name) | Cost-controlled Athena workgroup name. |
<!-- END_TF_DOCS -->