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
| [aws_identitystore_group.data_engineers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_identitystore_group.platform_admins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_ssoadmin_account_assignment.data_engineer_nonprod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_account_assignment.data_engineer_production](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_account_assignment.organization_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_account_assignment.platform_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_customer_managed_policy_attachment.query_editor_nonprod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_customer_managed_policy_attachment) | resource |
| [aws_ssoadmin_customer_managed_policy_attachment.query_editor_production](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_customer_managed_policy_attachment) | resource |
| [aws_ssoadmin_customer_managed_policy_attachment.region_guardrail_nonprod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_customer_managed_policy_attachment) | resource |
| [aws_ssoadmin_customer_managed_policy_attachment.region_guardrail_production](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_customer_managed_policy_attachment) | resource |
| [aws_ssoadmin_managed_policy_attachment.organization_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_managed_policy_attachment) | resource |
| [aws_ssoadmin_managed_policy_attachment.platform_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_managed_policy_attachment) | resource |
| [aws_ssoadmin_permission_set.data_engineer_nonprod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_permission_set.data_engineer_production](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_permission_set.organization_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_permission_set.platform_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_permission_set_inline_policy.data_engineer_nonprod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set_inline_policy) | resource |
| [aws_ssoadmin_permission_set_inline_policy.data_engineer_production](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set_inline_policy) | resource |
| [aws_ssoadmin_instances.organization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_groups"></a> [create\_groups](#input\_create\_groups) | Create the PlatformAdmins and DataEngineers groups instead of using existing group IDs. | `bool` | `false` | no |
| <a name="input_data_engineers_group_id"></a> [data\_engineers\_group\_id](#input\_data\_engineers\_group\_id) | Existing DataEngineers group ID. Ignored when create\_groups is true. | `string` | `null` | no |
| <a name="input_data_engineers_group_name"></a> [data\_engineers\_group\_name](#input\_data\_engineers\_group\_name) | Display name used when creating or documenting the data engineers group. | `string` | `"DataEngineers"` | no |
| <a name="input_human_policy_prefix"></a> [human\_policy\_prefix](#input\_human\_policy\_prefix) | Prefix of the account-level customer-managed policies attached to the DataEngineer permission sets. | `string` | `"jtrusty-data-platform"` | no |
| <a name="input_identity_store_id"></a> [identity\_store\_id](#input\_identity\_store\_id) | Identity Center identity store ID. Null uses the discovered instance's store. | `string` | `null` | no |
| <a name="input_instance_arn"></a> [instance\_arn](#input\_instance\_arn) | Identity Center instance ARN. Null discovers the organization instance, which cannot be created by Terraform and must already be enabled. | `string` | `null` | no |
| <a name="input_management_account_id"></a> [management\_account\_id](#input\_management\_account\_id) | Organizations management account that hosts no platform workloads. | `string` | n/a | yes |
| <a name="input_organization_admin_user_ids"></a> [organization\_admin\_user\_ids](#input\_organization\_admin\_user\_ids) | Named Identity Center user IDs granted exceptional management-account access. | `set(string)` | n/a | yes |
| <a name="input_permission_set_prefix"></a> [permission\_set\_prefix](#input\_permission\_set\_prefix) | Prefix applied to every managed permission set name. | `string` | `""` | no |
| <a name="input_platform_admins_group_id"></a> [platform\_admins\_group\_id](#input\_platform\_admins\_group\_id) | Existing PlatformAdmins group ID. Ignored when create\_groups is true. | `string` | `null` | no |
| <a name="input_platform_admins_group_name"></a> [platform\_admins\_group\_name](#input\_platform\_admins\_group\_name) | Display name used when creating or documenting the platform administrators group. | `string` | `"PlatformAdmins"` | no |
| <a name="input_workload_accounts"></a> [workload\_accounts](#input\_workload\_accounts) | Workload environment names mapped to their dedicated AWS account IDs. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_group_ids"></a> [group\_ids](#output\_group\_ids) | Group IDs assigned to the managed permission sets. |
| <a name="output_identity_store_id"></a> [identity\_store\_id](#output\_identity\_store\_id) | Confirmed Identity Center identity store ID. |
| <a name="output_instance_arn"></a> [instance\_arn](#output\_instance\_arn) | Identity Center instance the permission sets belong to. |
| <a name="output_permission_set_arns"></a> [permission\_set\_arns](#output\_permission\_set\_arns) | Managed Identity Center permission set ARNs. |
<!-- END_TF_DOCS -->