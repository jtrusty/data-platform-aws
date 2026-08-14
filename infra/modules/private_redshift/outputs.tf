output "vpc_id" {
  description = "Private analytics VPC ID."
  value       = aws_vpc.analytics.id
}

output "private_subnet_ids" {
  description = "Redshift private subnet IDs keyed by availability zone."
  value       = { for zone, subnet in aws_subnet.redshift : zone => subnet.id }
}

output "security_group_id" {
  description = "Dedicated no-ingress Redshift security group ID."
  value       = aws_security_group.redshift.id
}

output "namespace_name" {
  description = "Redshift Serverless namespace name."
  value       = aws_redshiftserverless_namespace.analytics.namespace_name
}

output "namespace_arn" {
  description = "Redshift Serverless namespace ARN."
  value       = aws_redshiftserverless_namespace.analytics.arn
}

output "workgroup_name" {
  description = "Redshift Serverless workgroup name."
  value       = aws_redshiftserverless_workgroup.analytics.workgroup_name
}

output "workgroup_arn" {
  description = "Redshift Serverless workgroup ARN."
  value       = aws_redshiftserverless_workgroup.analytics.arn
}

output "monthly_rpu_hours" {
  description = "Hard monthly Redshift compute limit in RPU-hours."
  value       = aws_redshiftserverless_usage_limit.compute.amount
}

output "base_capacity" {
  description = "Configured Redshift base capacity in RPUs."
  value       = aws_redshiftserverless_workgroup.analytics.base_capacity
}

output "max_capacity" {
  description = "Configured Redshift maximum capacity in RPUs."
  value       = aws_redshiftserverless_workgroup.analytics.max_capacity
}

output "enhanced_vpc_routing" {
  description = "Whether Redshift data traffic is forced through the customer VPC."
  value       = aws_redshiftserverless_workgroup.analytics.enhanced_vpc_routing
}

output "publicly_accessible" {
  description = "Whether the Redshift workgroup has a public endpoint; always false."
  value       = aws_redshiftserverless_workgroup.analytics.publicly_accessible
}
