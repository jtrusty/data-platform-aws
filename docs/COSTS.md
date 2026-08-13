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
| Networking | None until a private workload exists | Avoids NAT gateway and interface-endpoint hourly charges |
| Redshift | Disabled until the analytics increment | Avoids compute and storage use before consumers exist |

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
- [Amazon Redshift pricing](https://aws.amazon.com/redshift/pricing/)

## Environment profiles

| Setting | Sandbox | Development | Production |
| --- | ---: | ---: | ---: |
| Landing retention | 7 days | 14 days | 30 days |
| Athena result retention | 7 days | 14 days | 30 days |
| Current artifact retention | 30 days | 90 days | 365 days |
| Noncurrent Bronze/artifact versions | 7 days | 30 days | 90 days |
| DynamoDB capacity | 1 RCU / 1 WCU | 1 RCU / 1 WCU | 1 RCU / 1 WCU |
| DynamoDB PITR | Off | Off | On |
| DynamoDB deletion protection | Off | On | On |
| Non-empty bucket teardown | Allowed | Denied | Denied |
| Secret recovery window | Immediate | 7 days | 30 days |

Bronze and Silver current objects do not expire automatically. Landing data,
reproducible Athena results, and old deployment artifacts do. Bronze and
artifact buckets retain object versions in every environment; production also
versions Silver for recovery, while nonproduction relies on reproducibility and
Iceberg snapshot maintenance. These are starting points to adjust from observed
volume and recovery requirements.

## Redshift Serverless and networking

Redshift Serverless removes server and cluster management, but the workgroup is
still deployed into a VPC. The planned low-cost configuration is:

```text
Query Editor / Step Functions / Lambda
              |
       Redshift Data API
              |
private Redshift Serverless workgroup (4 base RPU)
              |
     free S3 gateway endpoint
              |
same-Region Silver and staging buckets
```

The workgroup will use private subnets, `publicly_accessible = false`, Enhanced
VPC Routing, and a security group that accepts TCP/5439 only from approved
workload security groups. VPCs, subnets, route tables, security groups, and the
S3 gateway endpoint have no hourly charge.

No NAT gateway or interface endpoint is created by default. Callers outside the
VPC use the Redshift Data API. A paid Data API interface endpoint is justified
only if a VPC-attached caller must keep API traffic entirely private. Direct
JDBC from a workstation requires an approved private network path and is not
part of the cheapest initial design.

When enabled, Redshift Serverless will default to the Ohio-supported minimum of
4 base RPU plus maximum-capacity and RPU-hour usage limits. It bills compute
while queries run and managed storage separately, so it remains disabled until
an analytics consumer is ready.

References:

- [Redshift resources in a VPC](https://docs.aws.amazon.com/redshift/latest/mgmt/managing-clusters-vpc.html)
- [Redshift Serverless capacity](https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-capacity.html)
- [Enhanced VPC Routing](https://docs.aws.amazon.com/redshift/latest/mgmt/enhanced-vpc-enabling-cluster.html)
- [Data API VPC endpoints](https://docs.aws.amazon.com/redshift/latest/mgmt/data-api-vpc-endpoint.html)

## Controls to add before production workloads

- AWS Budgets with email alerts at small absolute thresholds per account.
- Cost Anomaly Detection for the organization payer.
- Athena workgroup scanned-byte limits and query-result expiration.
- Redshift Serverless RPU-hour limits before enabling the workgroup.
- CloudWatch retention on every workload-created log group.
- Review measured S3 usage before adding paid storage transitions.

Do not add NAT gateways, blanket interface endpoints, speculative secrets,
always-on compute, frequent crawlers, or unlimited log/version retention without
a measured requirement and an explicit cost review.
