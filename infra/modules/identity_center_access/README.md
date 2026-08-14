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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_data_engineers_group_id"></a> [data\_engineers\_group\_id](#input\_data\_engineers\_group\_id) | DataEngineers Identity Center group ID. | `string` | `"619b5560-5001-707a-8057-b239ffbd3ae1"` | no |
| <a name="input_identity_store_id"></a> [identity\_store\_id](#input\_identity\_store\_id) | Organization IAM Identity Center identity store ID. | `string` | `"d-9a675d55f3"` | no |
| <a name="input_instance_arn"></a> [instance\_arn](#input\_instance\_arn) | Organization IAM Identity Center instance ARN. | `string` | `"arn:aws:sso:::instance/ssoins-6684759f0418edd4"` | no |
| <a name="input_organization_admin_user_ids"></a> [organization\_admin\_user\_ids](#input\_organization\_admin\_user\_ids) | Named Identity Center user IDs granted exceptional management-account access. | `set(string)` | n/a | yes |
| <a name="input_platform_admins_group_id"></a> [platform\_admins\_group\_id](#input\_platform\_admins\_group\_id) | PlatformAdmins Identity Center group ID. | `string` | `"118b3590-f061-7088-bff1-cc1c9f78d5c3"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity_store_id"></a> [identity\_store\_id](#output\_identity\_store\_id) | Confirmed Identity Center identity store ID. |
| <a name="output_permission_set_arns"></a> [permission\_set\_arns](#output\_permission\_set\_arns) | Managed Identity Center permission set ARNs. |
<!-- END_TF_DOCS -->