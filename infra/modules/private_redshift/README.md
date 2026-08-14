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
| [aws_cloudwatch_log_group.redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_redshiftserverless_namespace.analytics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshiftserverless_namespace) | resource |
| [aws_redshiftserverless_usage_limit.compute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshiftserverless_usage_limit) | resource |
| [aws_redshiftserverless_workgroup.analytics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshiftserverless_workgroup) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.analytics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Exactly three distinct Ohio availability zones for Redshift Serverless. | `list(string)` | <pre>[<br/>  "us-east-2a",<br/>  "us-east-2b",<br/>  "us-east-2c"<br/>]</pre> | no |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account that owns the private warehouse. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region containing the private warehouse. | `string` | `"us-east-2"` | no |
| <a name="input_base_capacity"></a> [base\_capacity](#input\_base\_capacity) | Base Redshift Serverless capacity in RPUs. | `number` | `4` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment identity used in every warehouse resource name. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Finite CloudWatch retention for all Redshift audit logs. | `number` | `14` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Maximum Redshift Serverless capacity in RPUs. | `number` | `4` | no |
| <a name="input_max_query_execution_seconds"></a> [max\_query\_execution\_seconds](#input\_max\_query\_execution\_seconds) | Maximum execution time for an individual Redshift query. | `number` | `900` | no |
| <a name="input_monthly_rpu_hours"></a> [monthly\_rpu\_hours](#input\_monthly\_rpu\_hours) | Monthly compute usage limit in aggregate RPU-hours; deactivation occurs when reached. | `number` | `16` | no |
| <a name="input_redshift_role_arn"></a> [redshift\_role\_arn](#input\_redshift\_role\_arn) | Exact Terraform-owned Redshift runtime role associated with the namespace. | `string` | n/a | yes |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | Environment-qualified data platform resource prefix. | `string` | n/a | yes |
| <a name="input_silver_bucket_arn"></a> [silver\_bucket\_arn](#input\_silver\_bucket\_arn) | Exact Silver bucket reachable through the private S3 endpoint. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory data-platform boundary tags. | `map(string)` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | Dedicated environment VPC CIDR. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_base_capacity"></a> [base\_capacity](#output\_base\_capacity) | Configured Redshift base capacity in RPUs. |
| <a name="output_enhanced_vpc_routing"></a> [enhanced\_vpc\_routing](#output\_enhanced\_vpc\_routing) | Whether Redshift data traffic is forced through the customer VPC. |
| <a name="output_max_capacity"></a> [max\_capacity](#output\_max\_capacity) | Configured Redshift maximum capacity in RPUs. |
| <a name="output_monthly_rpu_hours"></a> [monthly\_rpu\_hours](#output\_monthly\_rpu\_hours) | Hard monthly Redshift compute limit in RPU-hours. |
| <a name="output_namespace_arn"></a> [namespace\_arn](#output\_namespace\_arn) | Redshift Serverless namespace ARN. |
| <a name="output_namespace_name"></a> [namespace\_name](#output\_namespace\_name) | Redshift Serverless namespace name. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Redshift private subnet IDs keyed by availability zone. |
| <a name="output_publicly_accessible"></a> [publicly\_accessible](#output\_publicly\_accessible) | Whether the Redshift workgroup has a public endpoint; always false. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Dedicated no-ingress Redshift security group ID. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | Private analytics VPC ID. |
| <a name="output_workgroup_arn"></a> [workgroup\_arn](#output\_workgroup\_arn) | Redshift Serverless workgroup ARN. |
| <a name="output_workgroup_name"></a> [workgroup\_name](#output\_workgroup\_name) | Redshift Serverless workgroup name. |
<!-- END_TF_DOCS -->