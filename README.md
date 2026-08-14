# AWS Data Platform

Terraform foundation for a small-team AWS data platform. The design protects
account-level privilege boundaries while giving data engineers broad freedom
inside resources named and tagged for the platform.

## Current milestone

This first increment establishes:

- a `mise`-managed, pinned Terraform toolchain;
- separate sandbox, development, and production roots and state boundaries;
- a reusable secure S3 bucket module;
- per-account state and GitHub OIDC bootstrap roots;
- Terraform-managed Identity Center permission sets and group assignments;
- cost-controlled Athena workgroups and Bronze/Silver Glue Catalog databases;
- a private, no-NAT analytics VPC and tightly capped Redshift Serverless warehouse;
- an organization CloudTrail recording management events in every account;
- GuardDuty, AWS Config, and VPC flow logs in every account, with per-check
  Security Hub deliberately off until a measured bill justifies it;
- a $25 monthly budget per account and an enforcing Athena monthly spend guard;
- region and billed-resource IAM guardrails on deployment and human sessions;
- credential-free Terraform tests for high-impact state, IAM, and S3 controls;
- pull-request plans, a reviewed-plan gate on production, and nightly drift
  detection using read-only per-environment plan roles;
- formatting, validation, linting, documentation, and security-scanning CI; and
- the target trust model in [SECURITY.md](SECURITY.md).

The state, Identity Center, GitHub OIDC, and deployment-role bootstrap is live
in all four accounts. The cheap-by-default S3, SQS, DynamoDB, and runtime-IAM
foundation is also live and drift-free in sandbox and development. Athena,
private networking, and Redshift are implemented and awaiting the ordered
bootstrap/workload promotion described below. Production remains intentionally
undeployed until a reviewed release tag is approved. See the dated deployment
record in [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) and the capacity, retention,
Free Tier, Athena, and Redshift choices in
[docs/COSTS.md](docs/COSTS.md).

## Local setup

Install [mise](https://mise.jdx.dev/), then run:

```bash
mise install
mise run check
```

No AWS credentials are needed for module tests or static checks. AWS
credentials will be needed only for planning or applying an environment.

Useful commands:

```bash
mise run fmt
mise run validate
mise run test
mise run lint
mise run docs
mise run security
mise run secrets
```

## Environment and account model

An AWS account is the closest AWS equivalent to an Azure subscription. We use
three dedicated workload accounts, not logical partitions in one account:

| Environment | Purpose | Deployment policy |
| --- | --- | --- |
| Sandbox | Disposable experiments, feature validation, teardown, and rebuilds | Manual feature deployment; shorter retention |
| Development | First persistent integration environment used by data engineers | Deploy from `main` after CI passes |
| Production | Stable workloads and production data | Promote the same tested commit with approval |

Each environment has a separate Terraform root, AWS account, state bucket,
deployment role, VPC, KMS keys, runtime roles, data stores, and resource prefix.
We do not use Terraform workspaces and never promote Terraform state:

```text
feature commit -> sandbox -> merge to main -> development -> approval -> production
```

The confirmed account layout is:

| Responsibility | Account ID | VPC CIDR |
| --- | --- | --- |
| Organizations management | `699599381258` | No workload VPC |
| Sandbox | `555044956444` | `10.40.0.0/16` |
| Development | `511492912574` | `10.50.0.0/16` |
| Production | `991278600180` | `10.60.0.0/16` |

The management account hosts no data-platform workloads and routine deployment
CI cannot assume a management-account role.

Remote-state values are deliberately not committed. Each workload account gets
its own versioned, encrypted state bucket. Bootstrap roots begin with local
state; after creating the bucket, copy `backend.tf.example` to the gitignored
`backend.tf` and migrate using `backend.hcl`. Environment roots use the
remote backend from their first apply. The AWS provider also uses
`allowed_account_ids`, so credentials for the wrong account fail immediately.

### IAM and bootstrap ownership

Nearly all IAM configuration belongs in Terraform. The one-time manual setup is:

1. Protect the management-account root with MFA; centrally manage and remove
   member-account root credentials where possible.
2. Enable the organization instance of IAM Identity Center.
3. Create the first administrative workforce identity and `Data Engineers` group.
4. Create temporary administrator sessions used only to apply bootstrap stacks.
5. Create GitHub Environments named `sandbox`, `development`,
   `production-plan`, and `production`; production requires `jtrusty` review.

Terraform then owns:

- Identity Center permission sets and account assignments;
- GitHub OIDC providers and one environment deployment role per workload account;
- Terraform state buckets, KMS keys, bucket policies, and state-lock access;
- DataEngineer policies, permissions boundaries, runtime roles, and PassRole rules.

Organizations OUs, baseline SCPs, account contacts, and delegated
administration are planned account-governance work, not part of this milestone.

Organization/Identity Center changes use a separate, manually approved OrgAdmin
Terraform root. Routine GitHub Actions receives no management-account access.
When a workload change depends on a new IAM boundary, the administrator applies
the organization and target-account bootstrap plans first. In particular, the
development prerequisite must be live before merge because `main` deploys
development automatically. The exact ordering is documented in the
[bootstrap contract runbook](docs/BOOTSTRAP.md#apply-bootstrap-contracts-before-workload-changes).

The bootstrap stack defines one secure state bucket and one GitHub-OIDC
deployment role inside each workload account. Workload state remains in its own
account. Only the small organization/bootstrap state may live in a tightly
controlled management-account bucket; it is never available to routine CI. No
static AWS keys are used.

State buckets deliberately use the separate
`jtrusty-dp-tfstate-*` namespace. DataEngineer policies exclude that
namespace, the state KMS keys, OIDC providers, and Terraform deployment roles.

### Promotion workflow

- Pull requests run tests and scanners. Same-repository pull requests also use
  the read-only production role to produce a plan; fork pull requests receive
  no AWS credentials.
- A feature commit may be manually deployed to the shared sandbox. Sandbox
  deployments are serialized and can be destroyed deliberately.
- Merging to protected `main` automatically applies that exact commit to development.
- Production is triggered from a protected release tag pointing to a
  development-tested commit. GitHub's `production` Environment requires review.
- Application packages are built once and promoted by immutable digest. A
  production workflow must not silently rebuild a different artifact.
- Each environment has a deployment concurrency group so two applies cannot race.
- Rollback redeploys a previously tested Git commit and artifact digest;
  Terraform state restoration is reserved for state corruption.

GitHub Actions is the normal deployment operator, not merely a lint runner.
GitHub signs an OIDC identity token describing the immutable repository and
selected GitHub Environment. AWS validates that token against the deployment
role's trust policy and returns short-lived credentials; Terraform then plans
and applies directly in the target account. GitHub stores no permanent AWS
credential, and each target account retains its own encrypted Terraform state.

Local administrator sessions were needed to create this OIDC/state bootstrap.
Future local applies are reserved for bootstrap changes and recovery; routine
sandbox, development, and production deployments use the workflow described in
[the bootstrap runbook](docs/BOOTSTRAP.md#how-github-actions-deploys).

## Inputs still needed

The Identity Center instance, temporary bootstrap administrator, centralized
root-access features, and root-credential audit are complete. The remaining
platform decisions are:

1. Decide required cost-center tags, baseline SCP restrictions, and any KMS
   requirements beyond the current customer-managed keys.
2. Identify the first source integrations and secret containers to provision.
3. Provide private budget-alert destinations; no email address is committed to
   this public repository.
4. Revisit data and log retention after observing real volume.

Centralized root access is enabled. The dated audit in
[`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md#verification-and-audit-commands) confirms
that the management root has MFA and no access keys, while all three member
accounts have no root password or long-lived root credentials.

No long-lived AWS access keys are required or expected. An administrator will
bootstrap remote state and a temporary Terraform deployment role. Engineers
will access AWS through IAM Identity Center or an equivalent federated role.

## Planned delivery sequence

1. Secure data foundation: KMS, lake/artifact/query buckets, SQS/DLQs, DynamoDB, and secret containers.
2. Identity boundary: DataEngineer permission set and four responsibility-based runtime roles.
3. Glue Catalog, cost-controlled Athena, private networking, and capped Redshift Serverless.
4. Workload patterns, Gold loading, and CloudWatch observability.
5. Live positive and negative IAM simulations plus deployed-resource checks.

Changes use Conventional Commits, for example `feat: add secure data foundation`.
