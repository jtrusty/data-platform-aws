# Architecture

How this platform is put together and why. Start with
[ONBOARDING.md](ONBOARDING.md) if you need to get something done today; this
document explains the shape.

## The idea that explains everything else

There are two layers, applied by two different operators.

```text
BOOTSTRAP layer  ->  applied by a human administrator, locally, through SSO
     state buckets and their KMS keys, GitHub OIDC trust, permissions
     boundaries, deployment and plan roles, Identity Center, organization audit

WORKLOAD layer   ->  applied by GitHub Actions through OIDC
     buckets, queues, tables, Glue, Athena, Redshift, alarms, budgets,
     detective controls
```

The deployment role cannot change its own trust policy, its permissions
boundary, or the OIDC provider. `ProtectBootstrapResources` denies exactly that.
A deployment role able to widen its own boundary is not a boundary, so anything
that expands what CI may do is a deliberate human action.

**The rule that follows:** if a change would let CI do something it could not do
yesterday -- a new AWS service, new trust, a new `iam:PassRole` target, another
Region or account -- it is a bootstrap change. Everything else is a merge. CI
tells you which by failing with `AccessDenied`.

## Repository layout

```text
infra/
  bootstrap/{management,sandbox,development,production}/  administrator-applied, one root per account
  organization/                                           administrator-applied, management account
  environments/{sandbox,development,production}/          CI-applied, one root per account
  modules/                                                ten modules, each with tests/
scripts/                                                  post-apply deployment scripts and their stub-based tests
.github/workflows/                                        deploy.yml, drift.yml
mise.toml                                                 every check CI runs, runnable locally
```

Three independent Terraform roots serve each environment: its bootstrap root,
its workload root, and the shared organization root. There is deliberately no
single large state.

## Modules

| Module | Responsibility |
| --- | --- |
| `state_backend` | Versioned, KMS-encrypted Terraform state bucket for one account |
| `account_bootstrap` | OIDC provider, deployment and plan roles, permissions boundaries, region and cost guardrail policies |
| `identity_center_access` | Permission sets and group assignments; all human access |
| `organization_audit` | Organization CloudTrail, audit bucket, management budget, GuardDuty, Config |
| `secure_bucket` | The S3 primitive: block public access, encryption, TLS-only policy, lifecycle, ownership controls |
| `data_foundation` | Platform buckets, SQS queues and dead-letter queues, DynamoDB, secret containers, runtime IAM roles |
| `athena_analytics` | Cost-capped Athena workgroup and the Bronze and Silver Glue databases |
| `private_redshift` | No-NAT analytics VPC, private Redshift Serverless, monthly usage limit |
| `platform_observability` | Alert topic, account budget, Athena spend guard, CloudWatch alarms |
| `platform_detection` | GuardDuty, AWS Config, Security Hub, VPC flow logs |

## Environments

| | Sandbox | Development | Production |
| --- | --- | --- | --- |
| Account | `555044956444` | `511492912574` | `991278600180` |
| VPC CIDR | `10.40.0.0/16` | `10.50.0.0/16` | `10.60.0.0/16` |
| Deploys on | Manual dispatch | Merge to `main` | `v*` tag with approval |
| Noncurrent version retention | 7 days | 7 days | 30 days |
| Athena monthly byte limit | 100 GiB | 200 GiB | 500 GiB |

Each environment is a separate AWS account with its own state, KMS keys, VPC,
runtime roles, and resource prefix. State is never promoted between accounts;
only commits are.

## Delivery pipeline

```text
pull request     -> quality checks, plus read-only plans for all three environments
merge to main    -> development applies automatically
tag v*           -> confirm that exact commit deployed successfully to development
                 -> plan production with a read-only role
                 -> approval gate on the production GitHub Environment
                 -> re-plan, and refuse to apply unless the resource-change
                    fingerprint matches the plan that was reviewed
                 -> apply
nightly 07:17Z   -> plan every deployed environment, fail on drift
```

The fingerprint gate exists so that an approver approves a diff rather than a
job. Plan files are never uploaded as workflow artifacts: this repository is
public and artifacts are world-readable.

Drift detection skips an environment whose state holds no resources, so an
undeployed production does not report its entire configuration as drift every
night. It starts covering an environment automatically on its first apply.

## Identity

Four layers that are easy to confuse:

```text
group (DataEngineers)
  -> account assignment, Terraform-managed
    -> permission set (DataEngineerNonProd)
      -> IAM role AWSReservedSSO_DataEngineerNonProd_<hash>, inside each assigned account
```

A permission set only materializes as an IAM role in the accounts it is assigned
to. `DataEngineerNonProd` covers sandbox and development, `DataEngineerProduction`
covers production, and both are assigned to the same `DataEngineers` group, so
joining that group grants production access as well.

| Permission set | Session | Scope |
| --- | --- | --- |
| `OrganizationAdmin` | 1 hour | Management account, assigned to a named user rather than a group |
| `PlatformAdmin` | 1 hour | All three workload accounts |
| `DataEngineerNonProd` | 4 hours | Sandbox and development |
| `DataEngineerProduction` | 2 hours | Production |

### How engineer permissions are drawn

Engineers hold service wildcards bounded by environment-prefixed resource ARNs,
rather than enumerated actions. Enumeration lost to the rate at which AWS adds
actions: three separate Glue failures in three days, each on an action that
accepts no resource at all. The boundary is drawn with denies instead.

| Deny | Protects |
| --- | --- |
| Resource policies and public access | Who can reach platform data from outside the account |
| Data movement | Cross-Region and cross-account copies whose destination is a request parameter the Region deny cannot see |
| Durability and retention | Whether data survives: bucket creation and deletion, version deletion, versioning, encryption, lifecycle |
| Cost controls | The caps themselves: Athena workgroup creation, Glue development endpoints, provisioned concurrency |

Glue is a documented exception that holds account-wide rather than
prefix-scoped, because many Glue actions accept no resource. AWS reached the
same conclusion in its own `AWSGlueConsoleFullAccess` policy.

`ec2:CreateTags` is deliberately withheld even though AWS grants it in that
policy. Platform tags are what the KMS and Redshift conditions in this policy
match on, so tag control would be privilege control.

## Cost design

Idle cost is roughly $6 to $8 per month, almost entirely the four Terraform
state KMS keys. The controls that hold it there:

- Redshift Serverless deactivates at 16 RPU-hours per month
- Athena enforces a 10 GiB per-query cutoff, and a Lambda disables the workgroup
  once month-to-date scanned bytes reach the environment's limit
- No NAT gateway, no interface endpoints, no idle compute -- and IAM denies
  creating any of them
- A Region deny confines every identity to `us-east-2`, so nothing accrues in an
  unwatched Region
- A $25 monthly budget per account, which alerts but cannot stop spend

See [COSTS.md](COSTS.md) for the full model.

## What the tests do and do not cover

Terraform tests use mocked providers. They verify intent: that a bucket blocks
public access, that a policy denies what it claims to deny, that a document fits
its IAM quota. They cannot verify what AWS will accept.

Every failure during the first live deployment was invisible to them:

- CloudTrail rejected an organization trail's bucket policy that was missing the
  management-account delivery path
- `CreateNamespace` requires `iam:CreateServiceLinkedRole` on the caller even
  when the role already exists
- `CreateWorkgroup` rejects a price-performance level unless the target is
  enabled
- Redshift Serverless returns configuration parameters that were not declared,
  producing a diff that never converged
- Read-only plan roles could not read services the deployment role could write

Live applies and nightly drift detection cover that class. `mise run contract`
covers a third class that types cannot express: that bootstrap roots start with
local state, that workflows pin action digests by SHA, that the analytics module
contains no NAT gateway, that no alert address is committed.
