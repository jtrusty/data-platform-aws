# AWS and IAM Identity Center Bootstrap

This runbook separates discovery, human sign-in, Terraform bootstrap, and
routine CI. It contains no static access keys and no secret values.

## What already exists

The following AWS-side objects were created manually before this Terraform
bootstrap:

- an organization instance of IAM Identity Center;
- Identity Center groups named `OrganizationAdmins`, `PlatformAdmins`, and
  `DataEngineers`; and
- the four AWS accounts in the table below.

| Purpose | Account ID |
| --- | --- |
| Organizations management | `699599381258` |
| Sandbox | `555044956444` |
| Development | `511492912574` |
| Production | `991278600180` |

The discovery values now fixed in Terraform are:

| Object | ID |
| --- | --- |
| Identity Center instance | `arn:aws:sso:::instance/ssoins-6684759f0418edd4` |
| Identity store | `d-9a675d55f3` |
| Permanent organization administrator | `c1bba500-a0e1-70e7-52c2-5101377f116d` |
| `OrganizationAdmins` | `b1bb85d0-60e1-7026-1ecc-206e3c4cb3cc` |
| `PlatformAdmins` | `118b3590-f061-7088-bff1-cc1c9f78d5c3` |
| `DataEngineers` | `619b5560-5001-707a-8057-b239ffbd3ae1` |

No permission sets, account assignments, state buckets, OIDC providers, or
deployment roles from this repository exist in AWS until the Terraform roots
below are applied.

## What SSO does

SSO is the permanent human-access mechanism, not a workaround for one local
machine:

```text
person -> group (or named management admin) -> permission set + account assignment
       -> AWSReservedSSO role in that account -> temporary session -> resources
```

Groups are not attached directly to S3 buckets, Lambdas, or other resources.
Terraform assigns a principal and permission set to an AWS account. IAM
Identity Center then provisions and controls an `AWSReservedSSO_*` IAM role in
that account. The permission-set policies on that role determine which
resources the principal can use. Workload access uses groups; management-account
administration is assigned directly to one named user so a group
membership change cannot silently grant organization-wide administration.

`aws configure sso` stores non-secret profile configuration. `aws sso login`
opens a browser, authenticates the person, and obtains short-lived credentials.
It does not create an IAM user or write a permanent AWS access key.

GitHub Actions uses a different federation path. GitHub presents an OIDC token
for one exact repository and GitHub Environment; AWS returns a short-lived
deployment-role session. Human SSO credentials are never copied into GitHub.

## Read-only discovery commands

These commands explain how the confirmed IDs were inspected. They do not grant
access by themselves:

```bash
aws sso-admin list-instances \
  --region us-east-2 \
  --profile organization-bootstrap

aws identitystore list-groups \
  --identity-store-id d-9a675d55f3 \
  --region us-east-2 \
  --profile organization-bootstrap

aws identitystore list-group-memberships \
  --identity-store-id d-9a675d55f3 \
  --group-id b1bb85d0-60e1-7026-1ecc-206e3c4cb3cc \
  --region us-east-2 \
  --profile organization-bootstrap

aws identitystore list-group-memberships \
  --identity-store-id d-9a675d55f3 \
  --group-id b1bb85d0-60e1-7026-1ecc-206e3c4cb3cc \
  --region us-east-2 \
  --query 'GroupMemberships[].MemberId.UserId' \
  --output text \
  --profile organization-bootstrap
```

## One manual chicken-and-egg step

Before Terraform can manage Identity Center, one person must already be able to
administer the management account. This is the temporary access that would be
used for the first live Terraform plan and apply; it was not used for this
credential-free repository implementation:

1. The permanent administrator is the named Identity Center user
   `c1bba500-a0e1-70e7-52c2-5101377f116d`.
2. In the Identity Center console, create or reuse a temporary administrative
   permission set and assign the bootstrap operator directly to management
   account `699599381258`.
3. Require MFA and use a one-hour session.
4. Remove this temporary permission set and assignment after the Terraform
   `OrganizationAdmin` assignment has been tested.

This bootstrap administrator is temporary scaffolding. Its session runs
Terraform once; it is not a long-lived IAM user and it does not manually create
every workload role. Terraform creates the permission sets and assignments,
and Identity Center provisions its own account roles.

## Configure the management SSO profile

Run the interactive wizard and select management account `699599381258` and
the temporary bootstrap permission set:

```bash
aws configure sso --profile organization-bootstrap
aws sso login --profile organization-bootstrap
aws sts get-caller-identity --profile organization-bootstrap
```

Use the Identity Center access-portal URL and the Region in which Identity
Center was enabled. The platform resources remain in `us-east-2` even if the
Identity Center home Region differs.

## Bootstrap management state

The state bucket must exist before it can store its own state. Initialize this
one root with local state, apply it, and then migrate that state into the new
bucket:

```bash
export AWS_PROFILE=organization-bootstrap

terraform -chdir=infra/bootstrap/management init -backend=false
terraform -chdir=infra/bootstrap/management plan \
  -out=/tmp/data-platform-management-bootstrap.tfplan
terraform -chdir=infra/bootstrap/management apply \
  /tmp/data-platform-management-bootstrap.tfplan

cp infra/bootstrap/management/backend.tf.example \
  infra/bootstrap/management/backend.tf
terraform -chdir=infra/bootstrap/management init \
  -migrate-state \
  -force-copy \
  -backend-config=backend.hcl.example
terraform -chdir=infra/bootstrap/management state list
```

The committed bootstrap root intentionally has no backend declaration. The
gitignored `backend.tf` is activated only after the bucket exists; otherwise
Terraform cannot initialize the S3 backend needed to create that same bucket.
The bucket policy requires explicit KMS headers for state uploads. Terraform's
native `.tflock` uploads are the narrow exception because they do not include
those headers; bucket-default KMS encryption still encrypts every lock object.

The management bucket stores only management bootstrap and organization access
state. It never stores workload state and routine GitHub CI cannot access it.

## Apply Identity Center access

The single permanent administrator ID is fixed in the organization root. No
person-specific variable file is needed.

This root creates the permanent permission sets and account matrix:

| Principal | Permission set | Accounts |
| --- | --- | --- |
| Named user `c1bba500-…-116d` | `OrganizationAdmin` | Management only |
| `PlatformAdmins` | `PlatformAdmin` | Sandbox, development, production |
| `DataEngineers` | `DataEngineerNonProd` | Sandbox and development |
| `DataEngineers` | `DataEngineerProduction` | Production |

```bash
export AWS_PROFILE=organization-bootstrap

terraform -chdir=infra/organization init \
  -backend-config=backend.hcl.example
terraform -chdir=infra/organization plan \
  -out=/tmp/data-platform-organization.tfplan
terraform -chdir=infra/organization apply \
  /tmp/data-platform-organization.tfplan
```

Sign out and back in, verify that `OrganizationAdmin` works, and only then
remove the temporary bootstrap permission set and assignment:

```bash
aws sso logout
aws configure sso --profile organization-admin
aws sso login --profile organization-admin
aws sts get-caller-identity --profile organization-admin
```

## Bootstrap each workload account

Configure one SSO profile per workload account. Select the `PlatformAdmin`
permission set when prompted:

```bash
aws configure sso --profile platform-sandbox
aws configure sso --profile platform-development
aws configure sso --profile platform-production
```

For each account, log in, confirm the account ID, apply the bootstrap locally,
and migrate its bootstrap state into that account's own state bucket. Sandbox
is shown here:

```bash
aws sso login --profile platform-sandbox
aws sts get-caller-identity \
  --profile platform-sandbox \
  --query Account \
  --output text

export AWS_PROFILE=platform-sandbox

terraform -chdir=infra/bootstrap/sandbox init -backend=false
terraform -chdir=infra/bootstrap/sandbox plan \
  -out=/tmp/data-platform-sandbox-bootstrap.tfplan
terraform -chdir=infra/bootstrap/sandbox apply \
  /tmp/data-platform-sandbox-bootstrap.tfplan
cp infra/bootstrap/sandbox/backend.tf.example \
  infra/bootstrap/sandbox/backend.tf
terraform -chdir=infra/bootstrap/sandbox init \
  -migrate-state \
  -force-copy \
  -backend-config=backend.hcl.example
terraform -chdir=infra/bootstrap/sandbox state list
```

Repeat with `development`/`platform-development` and
`production`/`platform-production`. Provider account allowlists make an apply
fail if the selected profile belongs to the wrong account.

Each workload bootstrap creates:

- an encrypted, versioned, TLS-only Terraform state bucket and KMS key;
- a GitHub OIDC provider;
- a tightly trusted deployment role with a permissions boundary;
- a runtime-role permissions boundary; and
- in production, a separate read-only planning role.

The deployment role can pass only the four approved runtime role ARNs to their
approved AWS services. It cannot replace runtime boundaries or modify its own
trust, boundary, OIDC provider, or protected state controls.

## GitHub configuration still required

Create GitHub Environments named `sandbox`, `development`, `production-plan`,
and `production`. Record the Terraform output role ARN for the corresponding
environment. Require a reviewer for `production`, prevent self-review, and
restrict production deployment to protected release tags. The required
production reviewer is GitHub user `jtrusty`.

## Root-user protection

An email alias only changes message delivery. It does not share root security
settings: each AWS account has a separate root identity, credentials, and MFA
configuration. MFA on management account `699599381258` therefore does not
automatically enable MFA on the three member accounts.

For this organization, prefer centralized root access over maintaining three
additional root passwords and MFA registrations:

1. Keep the management-account root protected with MFA and no access keys.
2. Enable IAM trusted access and centralized root credential management.
3. Audit sandbox, development, and production root credentials.
4. Remove member-account root credentials after confirming emergency access.

### Centralized root-access commands

The following commands were run manually from the management-account SSO
session on 2026-08-13. They are organization-level security bootstrap actions,
not ordinary platform deployment steps:

```bash
aws organizations enable-aws-service-access \
  --service-principal iam.amazonaws.com \
  --profile organization-admin

aws iam enable-organizations-root-credentials-management \
  --profile organization-admin

aws iam enable-organizations-root-sessions \
  --profile organization-admin
```

The commands have distinct purposes:

1. `enable-aws-service-access` establishes trusted access between AWS
   Organizations and IAM. Without it, IAM cannot centrally manage root access
   for member accounts.
2. `enable-organizations-root-credentials-management` allows the management
   account to discover and remove long-lived root credentials in member
   accounts. It does not delete credentials by itself.
3. `enable-organizations-root-sessions` allows a management-account
   administrator to request a short-lived, task-scoped root session for a
   member account. It does not create a member root password or access key.

These commands do not enable MFA. Credential-less member accounts do not need
an MFA device because there is no root password with which anyone can sign in.
The management-account root remains a separate identity and must retain its
own MFA protection.

### Verification and audit commands

First verify the caller. This prevents an organization-level command from
being run against the wrong account or role:

```bash
aws sts get-caller-identity \
  --profile organization-admin \
  --query '{Account:Account,Arn:Arn}' \
  --output json
```

At bootstrap time this returned management account `699599381258` and the
temporary `AWSReservedSSO_BootstrapAdministrator_*` role. After the permanent
Terraform assignment is applied, repeat the check and expect the
`AWSReservedSSO_OrganizationAdmin_*` role instead.

Verify that both centralized root features are enabled:

```bash
aws iam list-organizations-features \
  --profile organization-admin \
  --output json
```

The expected enabled feature names are `RootCredentialsManagement` and
`RootSessions`.

The management account can be inspected directly. The query returns root
password, access-key, signing-certificate, and MFA indicators in that order:

```bash
aws iam get-account-summary \
  --profile organization-admin \
  --query '[SummaryMap.AccountPasswordPresent,SummaryMap.AccountAccessKeysPresent,SummaryMap.AccountSigningCertificatesPresent,SummaryMap.AccountMFAEnabled]' \
  --output text
```

Member accounts are audited with a 15-minute session limited by AWS's
`IAMAuditRootUserCredentials` task policy. This reusable shell function keeps
the temporary credentials in process memory, does not print them, and clears
the shell variables after each check:

```bash
export AWS_PROFILE=organization-admin
export AWS_REGION=us-east-2
export AWS_PAGER=""

audit_member_root() {
  local account_name="$1"
  local account_id="$2"
  local credentials access_key secret_key session_token summary

  credentials="$(aws sts assume-root \
    --target-principal "$account_id" \
    --task-policy-arn arn=arn:aws:iam::aws:policy/root-task/IAMAuditRootUserCredentials \
    --duration-seconds 900 \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)"
  read -r access_key secret_key session_token <<< "$credentials"

  summary="$(AWS_ACCESS_KEY_ID="$access_key" \
    AWS_SECRET_ACCESS_KEY="$secret_key" \
    AWS_SESSION_TOKEN="$session_token" \
    aws iam get-account-summary \
      --query '[SummaryMap.AccountPasswordPresent,SummaryMap.AccountAccessKeysPresent,SummaryMap.AccountSigningCertificatesPresent,SummaryMap.AccountMFAEnabled]' \
      --output text)"

  unset credentials access_key secret_key session_token
  printf '%s\t%s\n' "$account_name" "$summary"
}

audit_member_root sandbox 555044956444
audit_member_root development 511492912574
audit_member_root production 991278600180
```

Never enable shell tracing around that function or copy the `assume-root`
response into a file, ticket, or CI log because the response contains temporary
credentials.

The audit performed on 2026-08-13 produced:

| Account | Root password | Root access keys | Signing certificates | Root MFA | Required action |
| --- | ---: | ---: | ---: | ---: | --- |
| Management `699599381258` | 1 | 0 | 0 | 1 | Keep MFA; do not create root access keys |
| Sandbox `555044956444` | 0 | 0 | 0 | 0 | None; keep the account credential-less |
| Development `511492912574` | 0 | 0 | 0 | 0 | None; keep the account credential-less |
| Production `991278600180` | 0 | 0 | 0 | 0 | None; keep the account credential-less |

An MFA value of `0` on the member accounts is expected here: their root
password and all other long-lived root credentials are absent. Do not create a
root password merely to attach MFA. If a future audit finds a member root
password or key, remove the credential through centralized root access; if it
must be retained for an exceptional reason, protect that account's root with
its own MFA device.

Deleting member-account root credentials is a separate privileged,
destructive security operation. No deletion was required by this audit.

The repository currently runs credential-free static CI only. A later delivery
adds plan/apply workflows after the AWS bootstrap roles exist. Do not store AWS
access keys in GitHub secrets.

## Local development commands used

The repository pins its tooling in `mise.toml`. The setup and verification
commands are:

```bash
mise install
mise run fmt
mise run validate
mise run test
mise run contract
mise run lint
mise run security
mise run secrets
mise run check
```

The remote was configured with:

```bash
git remote add origin https://github.com/jtrusty/data-platform-aws.git
```

No `terraform apply`, Identity Center assignment change, or platform-resource
creation command was run while building this repository milestone. The three
centralized root-access enablement commands above were the only manual IAM or
Organizations mutations; all subsequent checks were read-only or used
audit-only temporary root sessions.

## Official AWS references

- [Organization instances of IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/organization-instances-identity-center.html)
- [Permission sets and Identity Center-managed roles](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html)
- [Configure IAM Identity Center authentication for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
- [Assign group access to AWS accounts](https://docs.aws.amazon.com/singlesignon/latest/userguide/assignusers.html)
- [Centralize root access for member accounts](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-enable-root-access.html)
- [List centralized root-access features](https://docs.aws.amazon.com/cli/latest/reference/iam/list-organizations-features.html)
- [Request a task-scoped member-account root session](https://docs.aws.amazon.com/cli/latest/reference/sts/assume-root.html)
- [IAM account-summary indicators](https://docs.aws.amazon.com/IAM/latest/APIReference/API_GetAccountSummary.html)
- [Root-user security best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html)
