locals {
  namespace_name = "${var.resource_prefix}-warehouse"
  subnet_by_zone = {
    for index, zone in var.availability_zones : zone => cidrsubnet(var.vpc_cidr, 8, index)
  }
  log_types = toset(["connectionlog", "useractivitylog", "userlog"])
}

resource "aws_vpc" "analytics" {
  cidr_block                       = var.vpc_cidr
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = false
  instance_tenancy                 = "default"
  tags                             = merge(var.tags, { Name = "${var.resource_prefix}-analytics", Purpose = "private-analytics" })
}

resource "aws_subnet" "redshift" {
  for_each = local.subnet_by_zone

  vpc_id                          = aws_vpc.analytics.id
  availability_zone               = each.key
  cidr_block                      = each.value
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false
  tags                            = merge(var.tags, { Name = "${var.resource_prefix}-redshift-${each.key}", Purpose = "redshift-private" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.analytics.id
  tags   = merge(var.tags, { Name = "${var.resource_prefix}-private", Purpose = "private-analytics" })
}

resource "aws_route_table_association" "redshift" {
  for_each = aws_subnet.redshift

  route_table_id = aws_route_table.private.id
  subnet_id      = each.value.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.analytics.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ReadApprovedSilverBucket"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource  = var.silver_bucket_arn
      },
      {
        Sid       = "ReadApprovedSilverObjects"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource  = "${var.silver_bucket_arn}/*"
      },
    ]
  })
  tags = merge(var.tags, { Name = "${var.resource_prefix}-s3", Purpose = "private-s3" })
}

resource "aws_security_group" "redshift" {
  name                   = "${var.resource_prefix}-redshift"
  description            = "Private Redshift Serverless with Data API access and no database ingress"
  vpc_id                 = aws_vpc.analytics.id
  revoke_rules_on_delete = true
  tags                   = merge(var.tags, { Name = "${var.resource_prefix}-redshift", Purpose = "redshift-private" })
}

resource "aws_vpc_security_group_egress_rule" "s3" {
  security_group_id = aws_security_group.redshift.id
  description       = "HTTPS to the regional S3 gateway endpoint only"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  tags              = merge(var.tags, { Purpose = "redshift-s3-egress" })
}

resource "aws_cloudwatch_log_group" "redshift" {
  for_each = local.log_types

  name              = "/aws/redshift/${local.namespace_name}/${each.key}"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { Purpose = "redshift-${each.key}" })
}

resource "aws_redshiftserverless_namespace" "analytics" {
  namespace_name       = local.namespace_name
  db_name              = "analytics"
  default_iam_role_arn = var.redshift_role_arn
  iam_roles            = [var.redshift_role_arn]
  log_exports          = local.log_types
  tags                 = merge(var.tags, { Purpose = "gold-warehouse" })

  depends_on = [aws_cloudwatch_log_group.redshift]
}

resource "aws_redshiftserverless_workgroup" "analytics" {
  namespace_name       = aws_redshiftserverless_namespace.analytics.namespace_name
  workgroup_name       = "${var.resource_prefix}-analytics"
  base_capacity        = var.base_capacity
  max_capacity         = var.max_capacity
  enhanced_vpc_routing = true
  publicly_accessible  = false
  port                 = 5439
  security_group_ids   = [aws_security_group.redshift.id]
  subnet_ids           = [for subnet in aws_subnet.redshift : subnet.id]

  price_performance_target {
    enabled = false
    level   = 1
  }

  config_parameter {
    parameter_key   = "enable_user_activity_logging"
    parameter_value = "true"
  }

  config_parameter {
    parameter_key   = "max_query_execution_time"
    parameter_value = tostring(var.max_query_execution_seconds)
  }

  config_parameter {
    parameter_key   = "require_ssl"
    parameter_value = "true"
  }

  tags = merge(var.tags, { Purpose = "gold-analytics" })
}

resource "aws_redshiftserverless_usage_limit" "compute" {
  resource_arn  = aws_redshiftserverless_workgroup.analytics.arn
  usage_type    = "serverless-compute"
  amount        = var.monthly_rpu_hours
  period        = "monthly"
  breach_action = "deactivate"
}
