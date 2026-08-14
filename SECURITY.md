# Security Model

> Status: state, GitHub OIDC bootstrap, deployment boundaries, and Identity
> Center access are applied and verified in AWS. The first S3, SQS, DynamoDB,
> and runtime-IAM foundation is live and drift-free in sandbox and development.
> Athena, the private analytics VPC, and Redshift are implemented and locally
> verified but not yet promoted; production remains intentionally undeployed.

## Trust boundary

The data platform is the primary operating boundary. Data engineers may broadly
operate platform data and workloads. Terraform/platform administrators retain
exclusive control of IAM, trust policies, permissions boundaries, VPC topology,
security groups, KMS administration, bucket and queue resource policies, and
account-level controls.

```text
DataEngineer (temporary federated session)
        |
        v
+-----------------------------------------------+
| data-platform-{environment}-*                 |
| S3, Lambda, SQS, Glue, Athena, Step Functions |
| DynamoDB, Redshift, Secrets, CloudWatch       |
+-----------------------------------------------+
                 trust boundary
+-----------------------------------------------+
| Terraform / platform administrator            |
| IAM, trust, KMS admin, VPC, SGs, policies      |
+-----------------------------------------------+
```

Sandbox, development, and production use separate Terraform state and dedicated
AWS accounts. Account isolation protects development from disposable sandbox
changes and limits production blast radius. The AWS Organizations management
account hosts no platform workloads.

| Environment | Account ID | VPC CIDR |
| --- | --- | --- |
| Sandbox | `555044956444` | `10.40.0.0/16` |
| Development | `511492912574` | `10.50.0.0/16` |
| Production | `991278600180` | `10.60.0.0/16` |

## Human access

Humans use IAM Identity Center or another temporary-role mechanism. The
Terraform-managed `DataEngineerNonProd` and `DataEngineerProduction` permission
sets provide broad platform operations without
`AdministratorAccess`, `PowerUserAccess`, IAM mutation, account/Organizations
administration, network-policy mutation, or KMS administration.

Query Editor v2 access uses a customer-managed owner-only `sqlworkbench`
policy. It deliberately excludes the AWS-managed policy's password-secret
permissions, so Query Editor cannot create or retrieve `sqlworkbench!*`
Secrets Manager secrets. Connections use temporary IAM credentials, while
engineers retain access only to `data-platform/{environment}/*` secrets.

Some AWS create APIs cannot be resource-scoped. Those exceptions will require
platform name prefixes and request tags where supported, and will be documented
in the policy. Authorization must not rely solely on mutable tags.

Identity Center permission sets and assignments are Terraform-managed after a
one-time manual bootstrap of the organization instance, initial administrator,
and groups. Workload access is assigned to groups. As a deliberate exception,
the `OrganizationAdmin` permission set is assigned directly to named user
`c1bba500-a0e1-70e7-52c2-5101377f116d` in the management account so group membership cannot silently grant
organization-wide administration. It is not used for daily platform work. See
[docs/BOOTSTRAP.md](docs/BOOTSTRAP.md).

## Roles and data boundaries

| Capability | Engineer | Ingest | Transform | Orchestrator | Redshift |
| --- | ---: | ---: | ---: | ---: | ---: |
| Manage IAM or trust | No | No | No | No | No |
| Pass approved platform roles | Yes | No | No | No | No |
| Read platform secrets | Yes | Limited | Limited | Limited | Limited |
| Write Bronze | Yes | Yes | No | No | No |
| Read Bronze | Yes | As needed | Yes | No | No |
| Write Silver | Yes | No | Yes | No | No |
| Execute Athena | Yes | No | Yes | Yes | No |
| Start Glue | Yes | No | As needed | Yes | No |
| Access Redshift | Yes | No | As needed | Data API | Yes |

The initial runtime roles are:

- `DataPlatformIngestRole`: source secrets, ingestion metadata, landing/Bronze,
  source queues, completion queues, and logs.
- `DataPlatformTransformRole`: Bronze read, Silver read/write, Glue Catalog,
  Athena/Glue transformation operations, and logs.
- `DataPlatformOrchestrationRole`: invoke approved Lambda functions and start
  approved Glue, Athena, SQS, and Redshift Data API operations. It has no broad
  data-plane access by default.
- `DataPlatformRedshiftRole`: read-only Silver objects and Glue Catalog
  metadata for approved Redshift loads.

Four shared roles intentionally trade per-function isolation for a model a small
team can understand. A new role is warranted only for a meaningful trust
boundary, such as an untrusted integration or materially broader credentials.

## PassRole and privilege escalation

`DataEngineer` will receive `iam:PassRole` only for explicit runtime role ARNs.
Each role will be paired with its approved `iam:PassedToService` values; a name
prefix alone is not sufficient. Runtime policies do not grant `sts:AssumeRole`,
IAM mutation, or `iam:PassRole`, and runtime trust policies name exact AWS
service principals.

Terraform owns the reserved platform-boundary tags. Engineer permissions will
not allow changing security-sensitive resource policies merely because the
resource is otherwise operable. In particular, bucket policies/Public Access
Block, queue policies, Lambda public access, secret resource policies, security
groups, and Redshift public accessibility remain Terraform-controlled.

## Secrets and encryption

Terraform creates secret containers under
`data-platform/{environment}/*`; it does not create secret versions or accept
secret values through committed variables. Engineers may retrieve only platform
secrets for incident response. Runtime roles receive narrower source/category
access.

A small number of environment-oriented customer-managed KMS keys is preferred
when a separate cryptographic boundary is required. Terraform state uses one
customer-managed key per account. The initial data lake instead uses
no-additional-cost service-owned encryption: SSE-S3, SSE-SQS, DynamoDB
AWS-owned encryption, and the Secrets Manager service key. Runtime roles never
receive key-policy changes, disablement, or deletion operations.

The S3 module supports either SSE-S3 or a supplied customer-managed KMS key
with Bucket Keys. It also enforces configurable versioning, lifecycle handling of
noncurrent versions and abandoned multipart uploads, bucket-owner enforcement,
all four Block Public Access controls, and a TLS-only bucket policy. A future
upload may omit encryption headers and use the bucket default; if it explicitly
requests encryption, the policy rejects an algorithm or KMS key inconsistent
with the configured bucket mode.

## Network flows

Redshift Serverless uses three private subnets and
`publicly_accessible = false`. Its dedicated security group has no ingress
rules; Query Editor and non-VPC workloads use the Redshift Data API. Enhanced
VPC Routing and a policy-restricted S3 gateway endpoint provide HTTPS read
access to the exact same-account Silver bucket. There is no internet gateway,
NAT gateway, public IP, IPv6 allocation, paid interface endpoint, or default
route. A later JDBC flow must add TCP/5439 from an exact workload security-group
reference, never an IPv4 or IPv6 world CIDR.

Lambda remains outside the VPC unless a function needs a private resource. The
initial private network uses only the free S3 gateway endpoint. Interface
endpoints and NAT are added only when their hourly cost and required private
flow are justified.

## Terraform and developer self-service

Terraform owns IAM, KMS, VPCs, security groups, buckets, resource policies,
baseline queues and tables, Redshift, Athena workgroups, and secret containers.
Engineers may self-serve prefixed/tagged Lambda, Glue, Step Functions, catalog,
and related application resources within the controls the service supports.
Application code, Glue scripts, SQL, and workflow definitions remain separately
deployable so routine data changes do not require an infrastructure apply.
Environment roots use fixed identities and AWS provider account allowlists;
state and live resources are never promoted between accounts.

Each workload account stores its own encrypted, versioned Terraform state and
lock file. Only that environment's GitHub OIDC deployment role and approved
platform administrators may access it. DataEngineer and runtime roles cannot
read Terraform state. The management account does not store workload state or
trust routine deployment CI; it may store only tightly controlled organization
and bootstrap state.

State buckets use `jtrusty-dp-tfstate-*`, outside the engineer-managed
`data-platform-*` namespace. State access is explicitly excluded from
DataEngineer and runtime policies because state and plan files can contain
sensitive values.

## Public repository and deployment identity

This repository is intentionally public. AWS account IDs, role ARNs, Identity
Center identifiers, region names, bucket names, CIDRs, and IAM policy documents
are identifiers or architecture metadata, not authentication credentials. Their
disclosure is accepted, but policies must remain secure even when an attacker
knows every identifier and policy statement.

No AWS access keys are stored in GitHub. GitHub Actions exchanges an ephemeral
OIDC token for temporary AWS role credentials. Each trust policy requires the
exact immutable GitHub repository identity and the expected GitHub environment;
fork pull requests cannot request an AWS deployment role. Production planning
uses a separate read-only role, while production apply requires the protected
`production` environment and a version tag whose exact commit has already
deployed successfully to development.

Repository controls include GitHub secret scanning, push protection, pinned
action revisions, CODEOWNERS, protected `main`, required Terraform checks, and
blocked force-pushes and branch deletion. With only one permanent repository
administrator, pull requests require passing checks but not an independent
approval. Adding a second trusted maintainer should be followed by requiring one
CODEOWNER approval and preventing self-review for production.

The deployment role holds no KMS key-management permissions. The platform
deliberately uses no customer-managed keys outside Terraform state, which the
bootstrap owns, so the role cannot create or administer one. It holds exactly
one service-linked-role grant, pinned to `redshift.amazonaws.com` and that
role's own ARN, because Redshift Serverless checks for that permission on every
CreateNamespace call whether or not the role already exists.

Terraform state, plan files, Identity Center SSO caches, local AWS configuration,
and `.env` files are ignored and must never be committed. Terraform may create
secret containers, but secret values are populated out of band so they do not
enter source, plans, state, or public workflow logs. Treat workflow logs as
public and avoid nonsensitive outputs that reveal more architecture than needed.

## Known risks and accepted tradeoffs

- An engineer who can change workload code can exercise that workload role's
  permissions. Runtime roles therefore remain strictly inside the platform
  boundary.
- Shared runtime roles increase blast radius compared with per-function roles;
  the simpler 4–8 role model is accepted for this team size.
- Direct engineer access to platform secrets is accepted for troubleshooting;
  retrieval remains logged and secrets require a rotation runbook.
- Tag condition support differs across AWS APIs. Prefix/ARN boundaries and
  explicit policy ownership backstop tags.
- IAM simulation does not fully model resource policies and permissions
  boundaries, so live read-only inspection supplements simulation.
- No NAT gateway or blanket interface endpoints are created by default. This
  reduces cost and complexity but requires an explicit change when a private
  workload needs additional service connectivity.
- Redshift uses its AWS-owned encryption key to avoid another monthly KMS-key
  charge. This can produce a Security Hub recommendation for customer-managed
  encryption; the cost-focused v1 tradeoff is accepted and documented.
- Redshift Gold uses native tables loaded from curated Silver objects. Direct
  Spectrum access to the Glue/Iceberg catalog is deferred because private
  Enhanced VPC Routing may require a paid Glue endpoint or NAT.
- The GitHub deployment role is the passwordless initial Redshift database
  administrator. Immediately after each apply, the same short-lived role runs
  the idempotent database bootstrap that grants a non-superuser
  `data_engineer` database role to the exact Identity Center role. No persistent
  database credential or secret is created. The bootstrap also revokes the
  default `CREATE` privilege on the `public` schema from `PUBLIC`, preventing
  other IAM-mapped runtime identities from creating Gold objects implicitly.
- A bootstrap-managed inline policy explicitly denies the production deployment
  role from deleting the namespace or workgroup. Intentional removal requires a
  PlatformAdmin to take a snapshot and deliberately remove that deletion guard
  first because the provider has no final-snapshot-on-destroy setting for
  Serverless namespaces.

## Audit logging

One organization CloudTrail records management events in every account and
region, with log file validation enabled, delivering to a dedicated
management-account bucket that blocks public access, denies non-TLS access, and
expires objects after a year. Only that trail may write to it. Object-level
data events are off by default because they bill per event; the module accepts
Terraform state bucket ARNs when an investigation needs object-level state
access history.

GuardDuty, AWS Config, and VPC flow logs are enabled in every account. Config
records an explicit resource-type list rather than all supported types, and flow
logs deliver to S3 rather than per-GB CloudWatch Logs ingestion.

Security Hub is deliberately off in every account. It is billed per control
check and would cost more than the rest of the platform combined at this stage;
benchmark scoring is a later decision to be made against a measured bill, not a
default. Its absence does not affect the trail, GuardDuty, Config, or flow logs.

Budget and alarm notifications publish to a per-account SNS topic that only
same-account Budgets and CloudWatch may write to, and never without TLS. The
subscribed address is supplied through a gitignored tfvars file locally and a
GitHub Environment secret in CI; it is marked sensitive so it is redacted from
plans printed into public workflow logs, and CI fails if an address is ever
committed to a tracked file.

## Region and billed-resource guardrails

The deployment role, the runtime permissions boundary, and both DataEngineer
permission sets deny any action outside `us-east-2`, exempting only the global
endpoints (IAM, STS, Organizations, account, support, and Identity Center) that
do not populate `aws:RequestedRegion`. An unused region is an unmonitored
region, and this is the cheapest place to stop that.

The deployment role is separately denied creation of NAT, internet, egress-only,
transit, and VPN gateways, Elastic IP allocation and association, VPC peering,
EBS volumes, EC2 instances, and interface or Gateway Load Balancer endpoints.
The deny is conditioned on endpoint type so the free S3 gateway endpoint keeps
working. These denies live in a separate attached policy rather than the
permissions boundary because an explicit Deny applies from any attached policy
and the boundary must stay inside the 6,144-character managed-policy quota.

Engineers hold full service access to the platform's own resources -- Athena,
DynamoDB, Glue, Lambda, CloudWatch Logs, SQS, Step Functions, S3, and Secrets
Manager -- bounded by the environment-prefixed ARNs each statement is attached
to. Enumerating individual actions was losing to the rate at which AWS adds
them, so the boundary is drawn with denies instead:

| Deny | Protects |
| --- | --- |
| Resource policies and public access | Who can reach platform data from outside the account: bucket, queue, Lambda, Glue, DynamoDB, and secret resource policies, S3 public-access and ownership controls, Lambda function URLs, cross-account replication |
| Data movement | Cross-Region and cross-account copies whose destination is a request parameter the Region deny cannot see: DynamoDB global tables and replicas, CloudWatch Logs subscription filters and destinations, secret replication |
| Durability and retention | Whether data survives: bucket creation and deletion, object version deletion, versioning, encryption configuration, lifecycle rules, and CloudWatch retention removal |
| Cost controls | The caps themselves: Athena workgroup creation and update, Glue development endpoints, Lambda provisioned concurrency |

Bucket creation is denied so every bucket carries the module's encryption,
versioning, lifecycle, and public-access controls. Object deletion is allowed
but version deletion is not, so a mistaken delete leaves a recoverable version.
An engineer-created Athena workgroup would carry no per-query scan cutoff and
would be invisible to the monthly spend guard, so only Terraform creates them.

Engineers also cannot delete or update the Terraform-owned Athena workgroup or
the Bronze and Silver catalog databases.

## Verification methodology

Pull requests run formatting, Terraform validation and tests, TFLint,
actionlint, module documentation checks, shell script tests against a stubbed
AWS CLI, Trivy configuration scanning, and Trivy secret scanning. Same-repository
pull requests also plan sandbox, development, and production with read-only
roles. A scheduled job plans every environment daily and fails on drift.

Production apply recomputes the fingerprint of its planned resource changes and
refuses to apply anything other than the diff that was reviewed in the
`production-plan` job. Plan files themselves are never uploaded as workflow
artifacts, because artifacts of a public repository are world-readable. Terraform tests use mocked
providers and focus on high-impact invariants rather than hundreds of shallow
assertions.

Before production deployment, post-deploy tests will add:

- positive and negative IAM policy simulations, including the
  `iam:PassedToService` context;
- inspection of inline and managed policies and role trust documents;
- S3 public-access, encryption, and TLS-policy checks;
- SQS encryption, redrive, and resource-policy checks;
- Redshift privacy/encryption and IPv4/IPv6 security-group checks; and
- post-deploy checks for source credentials and plaintext secret material in
  deployed configuration. Committed source is secret-scanned on every PR.

Scanner suppressions must be inline, narrow, and justified. A scanner result is
not proof of authorization behavior; developer-positive tests and denied-action
tests are both release criteria.

## Reporting a security issue

Do not open a public issue containing credentials, account identifiers, or
exploit details. Contact the repository owners through the organization's
private security-reporting channel. Rotate any exposed credential immediately.
