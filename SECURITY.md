# Security Model

> Status: state, GitHub OIDC bootstrap, deployment boundaries, and Identity
> Center access are applied and verified in AWS. Runtime roles and platform
> services remain planned.

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
- `DataPlatformRedshiftRole`: Silver Iceberg, Glue Catalog, approved staging
  paths, and required KMS cryptographic use.

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

A small number of environment-oriented customer-managed KMS keys is preferred.
Key administration and cryptographic use are separate. Runtime roles never
receive key-policy changes, disablement, or deletion operations.

The initial S3 module defaults new objects to the supplied customer-managed KMS
key with Bucket Keys. It also enforces versioning, lifecycle handling of
noncurrent versions and abandoned multipart uploads, bucket-owner enforcement,
all four Block Public Access controls, and a TLS-only bucket policy. A future
policy can require the exact KMS key on every explicit upload if that stronger
boundary is needed; the current default does not reject an explicitly requested
alternative encryption mode.

## Network flows

Redshift Serverless will use private subnets and
`publicly_accessible = false`. Its security group will allow TCP/5439 only from
explicit workload security-group references, never IPv4 or IPv6 world CIDRs.
Enhanced VPC Routing will be enabled where supported.

Lambda remains outside the VPC unless a function needs a private resource. The
initial private network will use S3 and DynamoDB gateway endpoints and no NAT
gateway. Interface endpoints are added only when their hourly cost and required
private flow are justified.

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

## Verification methodology

Pull requests run formatting, Terraform validation and tests, TFLint, Trivy
configuration scanning, and Trivy secret scanning. Terraform tests use mocked
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
