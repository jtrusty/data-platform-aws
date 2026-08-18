# Onboarding

What to do in your first day, how to make a change safely, and what to do when
something is denied. Read [ARCHITECTURE.md](ARCHITECTURE.md) alongside this for
why the platform is shaped the way it is.

## Day one

### 1. Local toolchain

```bash
mise install
mise run check
```

`mise run check` runs the entire CI gate: formatting, Terraform validation,
Terraform tests, the contract checks, TFLint, actionlint, shell parsing, shell
tests, module documentation, and both Trivy scans. It needs no AWS credentials.
If it passes locally, CI passes too, minus anything that requires real AWS.

### 2. AWS access

Ask an administrator to add you to the `DataEngineers` Identity Center group.
That single group grants sandbox, development, **and production**, so treat the
request accordingly.

Sign in at the AWS access portal, not the console login page. Identity Center
users have no account ID and no IAM user; the portal lists the accounts you can
open.

For CLI access, configure one profile per account:

```bash
aws configure sso --profile sandbox-engineer
aws sso login --profile sandbox-engineer
```

Two clocks apply. The role session lasts 4 hours in non-production and 2 in
production; the portal token lasts longer and is what you re-authenticate when
the CLI says your session expired.

### 3. Orient yourself

Read, in order: [ARCHITECTURE.md](ARCHITECTURE.md), [SECURITY.md](../SECURITY.md),
[COSTS.md](COSTS.md). Then look at one workload root end to end --
`infra/environments/development/main.tf` is about eighty lines and calls every
module the platform has.

## Making a change

### Decide which layer you are touching

Ask one question: **would this let CI do something it could not do yesterday?**

| Change | Layer | Who applies |
| --- | --- | --- |
| Bucket, queue, table, Glue job, Athena or Redshift setting, alarm, budget, retention | Workload | CI, on merge |
| A new runtime role under the existing boundary | Workload | CI, on merge |
| A new AWS service the deployment role has never used | Bootstrap | Administrator |
| A new `iam:PassRole` target | Bootstrap | Administrator |
| Permissions boundary or trust policy | Bootstrap | Administrator |
| Engineer permissions, permission sets, group assignments | Organization root | Administrator |
| Another Region or account | Bootstrap | Administrator |

The deployment role holds these services: `athena`, `budgets`, `cloudwatch`,
`config`, `dynamodb`, `ec2`, `glue`, `guardduty`, `lambda`, `logs`,
`redshift-data`, `redshift-serverless`, `securityhub`, `sns`, `sqs`, `states`,
plus scoped S3, Secrets Manager, KMS-free IAM, and state access. Anything
outside that list needs a bootstrap change first.

### The normal loop

```bash
git switch -c feat/your-change
# edit
mise run check
git commit
git push -u origin feat/your-change
gh pr create
```

The pull request runs the quality gate and plans all three environments with
read-only roles. Read the plans. Merging applies development automatically.

`main` is protected with linear history and admin enforcement, so changes land
through a pull request and a rebase merge. Direct pushes are refused.

### Applying a bootstrap change

Bootstrap and organization roots are applied by an administrator, in this order:

```bash
aws sso login --profile organization-admin

cd infra/bootstrap/sandbox      && AWS_PROFILE=sandbox-admin     terraform apply
cd infra/bootstrap/development  && AWS_PROFILE=development-admin terraform apply
cd infra/bootstrap/production   && AWS_PROFILE=production-admin  terraform apply
cd infra/organization           && AWS_PROFILE=organization-admin terraform apply
```

Apply the workload accounts before the organization root: the permission sets
reference customer-managed policies that the account bootstrap creates.

Always read the plan. A bootstrap plan should never destroy anything. If it
proposes a destroy, stop and work out why.

After a permission-set change, affected users must sign out and back in.
Identity Center bakes the policy into the role session at sign-in, so an
existing session keeps the old permissions.

### Deploying

| Target | How |
| --- | --- |
| Sandbox | `gh workflow run deploy.yml --ref main -f target=sandbox` |
| Development | Merge to `main` |
| Production | `git tag v0.1.0 && git push --tags`, then approve the environment |

Production additionally requires that the exact commit already deployed
successfully to development, and that the plan at apply time matches the plan
that was reviewed.

## When something is denied

`AccessDenied` is usually the design working, not a bug. Work through it in this
order.

**1. Which identity failed?** The error names the role. `AWSReservedSSO_DataEngineer*`
is a human session; `jtrusty-data-platform-terraform-deploy-*` is CI;
`jtrusty-data-platform-terraform-plan-*` is a pull-request or drift plan.

**2. Is it the Region deny?** Every identity is confined to `us-east-2`. A
console left in another Region produces confusing denials.

**3. Is it deliberate?** Check the deny statements in
`infra/modules/identity_center_access/policies.tf`. Bucket creation, version
deletion, resource policies, public access, Athena workgroup creation, and Glue
development endpoints are all denied on purpose.

**4. Is it a genuine gap?** If the action is ordinary work that no deny covers,
it is a gap. Add it, with a preference for the shape AWS itself uses: check the
relevant AWS managed policy first.

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess \
  --version-id "$(aws iam get-policy --policy-arn arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess --query 'Policy.DefaultVersionId' --output text)" \
  --query 'PolicyVersion.Document'
```

Do not copy such a policy wholesale. `AWSGlueConsoleFullAccess` includes
`ec2:CreateTags`, `ec2:RunInstances`, CloudFormation stack mutation, and
`s3:CreateBucket`, all of which this platform withholds for reasons documented
in [SECURITY.md](../SECURITY.md).

**5. Adding a new service to CI.** Update the deployment role *and* the plan
role together. They are separate policies in `account_bootstrap`, and forgetting
the plan role produces a failure that only appears in an environment where the
resource already exists.

## Operational tasks

### Nightly drift failed

Open the run and identify the environment. Drift means live infrastructure no
longer matches `main`.

- **Sandbox** commonly drifts because it deploys from feature branches by
  design. Redeploy it from `main` to clear it.
- **Development or production** drifting means an out-of-band change. Read the
  plan before applying anything.

### An Athena workgroup was disabled

The monthly byte limit was reached and the spend guard disabled it. That is the
cost control working. Re-enabling is deliberate: raise
`athena_monthly_bytes_limit` for that environment, or re-enable the workgroup
after understanding what consumed the budget.

### Redshift became unavailable

The workgroup deactivated at its monthly RPU-hour usage limit. Same reasoning as
above.

### A budget alert arrived

Budgets alert, they do not stop spend, and their data lags several hours. Check
Cost Explorer for the driver. The Athena and Redshift caps are the controls that
actually halt spend.

### Recovering a deleted object

Object deletion leaves a recoverable version; engineers cannot delete versions.
List versions and restore by version ID. Recovery windows are 7 days outside
production and 30 days in it. Landing and Athena results are unversioned by
design and are not recoverable.

## Conventions

- Conventional Commits, for example `feat: add secure data foundation`
- Resources are named `data-platform-{environment}-*`; catalog databases use
  `data_platform_{environment}_*`
- Every resource carries `Environment`, `ManagedBy`, `Owner`, and `Platform` tags
- Alert addresses and secret values never enter the repository; a contract check
  fails the build if an address appears in a tracked file
- Module documentation is generated: run `mise run docs` after changing a
  module's inputs or outputs
