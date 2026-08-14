<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_state_backend"></a> [state\_backend](#module\_state\_backend) | ../state_backend | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.deployment_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.deployment_guardrails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.human_region_guardrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.query_editor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.runtime_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.terraform_deploy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.terraform_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.protect_production_warehouse](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.terraform_deploy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.terraform_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.deployment_guardrails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_service_linked_role.detection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_iam_service_linked_role.redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Exact workload account ID. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Exact workload environment. | `string` | n/a | yes |
| <a name="input_github_environment"></a> [github\_environment](#input\_github\_environment) | GitHub Environment allowed to assume the deployment role. | `string` | n/a | yes |
| <a name="input_github_owner_id"></a> [github\_owner\_id](#input\_github\_owner\_id) | Immutable GitHub repository owner ID. | `string` | `"6896625"` | no |
| <a name="input_github_repository_id"></a> [github\_repository\_id](#input\_github\_repository\_id) | Immutable GitHub repository ID. | `string` | `"1333254672"` | no |
| <a name="input_github_repository_name"></a> [github\_repository\_name](#input\_github\_repository\_name) | Immutable GitHub repository name component. | `string` | `"data-platform-aws"` | no |
| <a name="input_github_repository_owner"></a> [github\_repository\_owner](#input\_github\_repository\_owner) | Immutable GitHub repository owner name component. | `string` | `"jtrusty"` | no |
| <a name="input_manage_detective_service_linked_roles"></a> [manage\_detective\_service\_linked\_roles](#input\_manage\_detective\_service\_linked\_roles) | Create the account-wide AWS Config, GuardDuty, and Security Hub service-linked roles. Set to false for an account where they already exist. | `bool` | `true` | no |
| <a name="input_manage_redshift_service_linked_role"></a> [manage\_redshift\_service\_linked\_role](#input\_manage\_redshift\_service\_linked\_role) | Create the account-wide Redshift service-linked role. Set to false for an account where it already exists; an existing managed role must be removed from state rather than destroyed. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mandatory bootstrap ownership tags. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_deployment_role_arn"></a> [deployment\_role\_arn](#output\_deployment\_role\_arn) | GitHub OIDC platform deployment role ARN. |
| <a name="output_plan_role_arn"></a> [plan\_role\_arn](#output\_plan\_role\_arn) | Read-only Terraform plan role ARN for this environment. |
| <a name="output_runtime_boundary_arn"></a> [runtime\_boundary\_arn](#output\_runtime\_boundary\_arn) | Bootstrap-owned runtime permissions boundary ARN. |
| <a name="output_state_bucket_name"></a> [state\_bucket\_name](#output\_state\_bucket\_name) | Environment Terraform state bucket name. |
| <a name="output_state_kms_key_arn"></a> [state\_kms\_key\_arn](#output\_state\_kms\_key\_arn) | Environment Terraform state KMS key ARN. |
<!-- END_TF_DOCS -->