# Cost Strategy

The platform defaults to the cheapest secure configuration and exposes material
capacity and retention choices through committed, non-secret
`foundation.auto.tfvars` files. Free Tier allowances reduce cost but are not a
security control or guarantee: eligibility and pricing can change, so billing
alerts remain necessary.

## Foundation baseline

| Service | Default | Cost rationale |
| --- | --- | --- |
| S3 | Five purpose-specific buckets using SSE-S3 | No fixed per-bucket or key charge; pay for stored data and requests |
| SQS | Two standard queues and two DLQs using SSE-SQS | No idle capacity charge; the first one million monthly requests are currently free |
| DynamoDB | One Standard table at 1 RCU and 1 WCU | Uses a small part of the payer-level 25 RCU/25 WCU monthly Free Tier allowance |
| Secrets Manager | No containers until an integration needs one | Each secret has a recurring charge; Terraform never stores its value |
| Runtime IAM | Four responsibility-based roles | IAM roles and policies have no direct hourly charge |
| Athena | Engine v3, enforced result bucket, 10 GiB per-query cutoff | No idle charge; standard SQL is billed by bytes scanned |
| Networking | Private VPC, three subnets, one route table, S3 gateway endpoint | These primitives have no hourly charge; no NAT or paid interface endpoint |
| Redshift | 4 base/maximum RPU, 16 RPU-hour monthly deactivation limit | Idles without compute charge and hard-stops near $6 of monthly compute at the current example rate |
| CloudTrail | One organization trail, management events only | The first copy of management events per account is free; only capped S3 storage is billed |

Terraform state intentionally retains a separate customer-managed KMS key in
each account. That key fee is accepted because state can contain sensitive
values and must not share its cryptographic boundary with workloads. Lake
buckets use S3-managed AES-256 encryption, queues use SQS-managed encryption,
and DynamoDB uses AWS-owned encryption. Encryption cannot be disabled through
tfvars.

Current official pricing references:

- [Amazon SQS pricing](https://aws.amazon.com/sqs/pricing/)
- [Amazon DynamoDB pricing and Free Tier](https://aws.amazon.com/dynamodb/pricing/)
- [AWS KMS pricing](https://aws.amazon.com/kms/pricing/)
- [AWS Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [Amazon Athena pricing](https://aws.amazon.com/athena/pricing/)
- [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/)
- [Amazon Redshift pricing](https://aws.amazon.com/redshift/pricing/)

## Environment profiles

| Setting | Sandbox | Development | Production |
| --- | ---: | ---: | ---: |
| Landing retention | 7 days | 14 days | 30 days |
| Athena result retention | 7 days | 14 days | 30 days |
| Athena per-query scan cutoff | 10 GiB | 10 GiB | 10 GiB |
| Redshift base / maximum | 4 / 4 RPU | 4 / 4 RPU | 4 / 4 RPU |
| Redshift monthly compute cutoff | 16 RPU-hours | 16 RPU-hours | 16 RPU-hours |
| Redshift audit-log retention | 7 days | 14 days | 30 days |
| Current artifact retention | 30 days | 90 days | 365 days |
| Noncurrent Bronze/artifact versions | 7 days | 7 days | 30 days |
| DynamoDB capacity | 1 RCU / 1 WCU | 1 RCU / 1 WCU | 1 RCU / 1 WCU |
| DynamoDB PITR | Off | Off | On |
| DynamoDB deletion protection | Off | On | On |
| Non-empty bucket teardown | Allowed | Denied | Denied |
| Secret recovery window | Immediate | 7 days | 30 days |

Bronze and Silver current objects do not expire automatically. Landing data,
reproducible Athena results, and old deployment artifacts do. Bronze, Silver,
and artifact buckets retain object versions in every environment, so a mistaken
delete leaves a recoverable version everywhere curated data lives, alongside
Iceberg snapshot maintenance. These are starting points to adjust from observed
volume and recovery requirements.

## Athena for Bronze and Silver

Athena is the default engine for ad hoc exploration and Bronze/Silver lake
transformations. It has no idle capacity charge. Standard SQL currently costs
$5 per TB scanned, so the enforced 10 GiB workgroup cutoff limits one query to
about $0.05. Columnar Parquet/Iceberg data, partition pruning, and selecting
only required columns usually reduce the actual scan further.

Each environment has one workgroup, an encrypted account-owned results prefix,
CloudWatch metrics, and baseline `data_platform_<environment>_bronze` and
`data_platform_<environment>_silver` Glue databases. The Glue Data Catalog's
first million objects and first million monthly requests are currently free.
S3 storage and request charges still apply.

## Redshift Serverless and networking

Redshift Serverless removes server and cluster management, but the workgroup is
still deployed into a VPC. The planned low-cost configuration is:

```text
Query Editor / Step Functions / Lambda
              |
       Redshift Data API
              |
private Redshift Serverless workgroup (4 base and maximum RPU)
              |
     free S3 gateway endpoint
              |
same-Region Silver bucket
```

The workgroup uses three private subnets, `publicly_accessible = false`,
Enhanced VPC Routing, TLS-required connections, and a security group with no
ingress rules. Query Editor v2 and automation use the Data API, so no JDBC rule
is needed. VPCs, subnets, route tables, security groups, and the S3 gateway
endpoint have no hourly charge.

No NAT gateway or interface endpoint is created by default. Callers outside the
VPC use the Redshift Data API. A paid Data API interface endpoint is justified
only if a VPC-attached caller must keep API traffic entirely private. Direct
JDBC from a workstation requires an approved private network path and is not
part of the cheapest initial design.

The workgroup uses the Ohio-supported minimum of 4 RPU for both base and maximum
capacity. AWS's default Balanced AI-driven price-performance scaling is
explicitly disabled because it can allocate billable extra compute and is not
recommended for 4-RPU workgroups. A monthly `deactivate` usage limit stops user queries at 16 aggregate
RPU-hours, approximately $6 of compute at the current $0.375/RPU-hour example
rate. Redshift bills managed storage and CloudWatch logs separately, and even
an empty namespace uses a small amount of managed storage. The account's $10
AWS Budget will be an alert rather than a hard cap once a private notification
address is supplied.

Gold marts live in native Redshift tables. Redshift can load curated Silver
objects through the free S3 gateway endpoint. Direct Spectrum/Glue access to
Silver Iceberg is intentionally deferred: with Enhanced VPC Routing, that path
may require a NAT gateway or paid Glue interface endpoint. It must be tested
and cost-reviewed before being enabled.

References:

- [Redshift resources in a VPC](https://docs.aws.amazon.com/redshift/latest/mgmt/managing-clusters-vpc.html)
- [Redshift Serverless capacity](https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-capacity.html)
- [Enhanced VPC Routing](https://docs.aws.amazon.com/redshift/latest/mgmt/enhanced-vpc-enabling-cluster.html)
- [Data API VPC endpoints](https://docs.aws.amazon.com/redshift/latest/mgmt/data-api-vpc-endpoint.html)

## Spend controls

Every account carries a $25 monthly cost budget with actual notifications at
50%, 80%, and 100% plus a forecast notification, so four accounts bound the
platform at $100/month of *alerting*. AWS Budgets only notifies: cost data lags
several hours and Budgets cannot stop spend without a budget action, which was
deliberately not enabled so an incident response cannot be locked out by its own
cost control.

Athena is the one service with no natural ceiling. Its per-query cutoff limits a
single query to 10 GiB, but nothing limits query volume, so an enforcing control
was added:

```text
Athena ProcessedBytes (daily)
      |
CloudWatch alarm at monthly allowance / 30
      |
   SNS alert topic ---> email
      |
   Lambda spend guard
      |
sums month-to-date ProcessedBytes
      |
 disables the workgroup once the monthly limit is reached
```

CloudWatch alarms cannot sum a calendar month, so the alarm fires on a daily
share and the guard function makes the monthly decision itself. Re-enabling a
disabled workgroup is a deliberate Terraform or console action. The monthly
limits are 100 GiB in sandbox, 200 GiB in development, and 500 GiB in
production: about $0.50, $1, and $2.50 of scan at $5/TB.

| Control | Enforcing? | Reaction time |
| --- | --- | --- |
| Athena per-query cutoff | Yes | Immediate, per query |
| Athena monthly guard | Yes, disables the workgroup | Minutes |
| Redshift usage limit | Yes, deactivates the workgroup | Minutes |
| Account budget | No, notification only | Hours |

## Detective controls

| Control | Idle cost | Cost shape |
| --- | ---: | --- |
| GuardDuty, 4 accounts | ~$0.25/mo | Per million analyzed CloudTrail events |
| VPC flow logs to S3 | ~$0.05/mo | Per GB stored; a no-NAT VPC produces very little |
| AWS Config | ~$1-3/mo | Per configuration item and rule evaluation; recording is limited to an explicit resource-type list rather than all supported types |
| Security Hub | **off** | Per control check; roughly $2-6 per account per month if enabled |

Security Hub is billed per security check, and the Foundational Security Best
Practices standard runs a few hundred controls per account, so it would have
been the largest line on an otherwise nearly free platform. It is off in every
account, including management, and defaults to off in both modules. Turn it on
per account with `enable_security_hub = true` once a measured bill justifies it;
if it is enabled, only the foundational standard is subscribed, because adding
CIS roughly doubles the charge for largely overlapping findings.

Flow logs are delivered to S3 rather than CloudWatch Logs because log ingestion
is billed per GB while S3 storage is not.

## Guardrails that keep an idle platform idle

Cost control is enforced in IAM, not only in review. Both the deployment role
and the DataEngineer permission sets are denied outside `us-east-2`, so nothing
can be created in an unmonitored region. The deployment role is additionally
denied every hourly-billed network and compute primitive: NAT, internet,
transit, and VPN gateways, Elastic IPs, VPC peering, EBS volumes, EC2
instances, and billed interface endpoints. The free S3 gateway endpoint is
explicitly still allowed.

CloudTrail is deliberately configured for the cheap half of its pricing model:
one organization trail, management events only, no CloudWatch Logs delivery,
no data events unless a named Terraform state bucket is passed in, SSE-S3
rather than a monthly customer-managed key, and a 365-day lifecycle expiry so
storage cannot grow without bound.

Redshift, Glue, and Lambda create log groups on first use with unlimited
retention. `scripts/enforce-log-retention.sh` runs after every apply and
applies the environment's retention to any group AWS created implicitly, so no
log group bills forever.

## Controls to add before production workloads

- AWS Budgets with email alerts at small absolute thresholds per account.
- Cost Anomaly Detection for the organization payer.
- Review measured S3 usage before adding paid storage transitions.

Do not add NAT gateways, blanket interface endpoints, speculative secrets,
always-on compute, frequent crawlers, or unlimited log/version retention without
a measured requirement and an explicit cost review.
