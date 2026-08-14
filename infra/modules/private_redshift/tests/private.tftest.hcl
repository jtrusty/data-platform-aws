mock_provider "aws" {}

override_resource {
  target = aws_redshiftserverless_workgroup.analytics
  values = {
    arn = "arn:aws:redshift-serverless:us-east-2:555044956444:workgroup/00000000-0000-0000-0000-000000000001"
  }
}

variables {
  aws_account_id     = "555044956444"
  availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]
  environment        = "sandbox"
  resource_prefix    = "data-platform-sandbox"
  redshift_role_arn  = "arn:aws:iam::555044956444:role/data-platform/runtime/data-platform-sandbox-redshift"
  silver_bucket_arn  = "arn:aws:s3:::data-platform-sandbox-silver-555044956444"
  vpc_cidr           = "10.40.0.0/16"

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Owner       = "data-platform"
    Platform    = "data-platform"
  }
}

run "creates_private_cost_capped_redshift" {
  command = apply

  assert {
    condition = (
      aws_vpc.analytics.cidr_block == "10.40.0.0/16" &&
      aws_vpc.analytics.enable_dns_support &&
      aws_vpc.analytics.enable_dns_hostnames
    )
    error_message = "The analytics VPC must retain its environment CIDR and DNS support."
  }

  assert {
    condition = (
      length(aws_subnet.redshift) == 3 &&
      toset([for subnet in aws_subnet.redshift : subnet.availability_zone]) == toset(var.availability_zones) &&
      alltrue([for subnet in aws_subnet.redshift : !subnet.map_public_ip_on_launch])
    )
    error_message = "Redshift requires three private subnets in distinct approved availability zones."
  }

  assert {
    condition = (
      length(aws_route_table_association.redshift) == 3 &&
      aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway" &&
      aws_vpc_endpoint.s3.service_name == "com.amazonaws.us-east-2.s3" &&
      alltrue([
        for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement :
        alltrue([
          for resource in flatten([statement.Resource]) :
          startswith(resource, "arn:aws:s3:::data-platform-sandbox-silver-555044956444")
        ])
      ])
    )
    error_message = "The private subnets must share a free S3 gateway endpoint restricted to the exact Silver bucket."
  }

  assert {
    condition     = length(aws_security_group.redshift.ingress) == 0
    error_message = "Query Editor and the Data API require no inbound database rule."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.s3.ip_protocol == "tcp" &&
      aws_vpc_security_group_egress_rule.s3.from_port == 443 &&
      aws_vpc_security_group_egress_rule.s3.to_port == 443 &&
      aws_vpc_security_group_egress_rule.s3.prefix_list_id == aws_vpc_endpoint.s3.prefix_list_id &&
      aws_vpc_security_group_egress_rule.s3.cidr_ipv4 == null &&
      aws_vpc_security_group_egress_rule.s3.cidr_ipv6 == null
    )
    error_message = "Redshift egress must be HTTPS to the S3 prefix list, never an open CIDR."
  }

  assert {
    condition = (
      aws_redshiftserverless_namespace.analytics.namespace_name == "data-platform-sandbox-warehouse" &&
      aws_redshiftserverless_namespace.analytics.db_name == "analytics" &&
      aws_redshiftserverless_namespace.analytics.default_iam_role_arn == var.redshift_role_arn &&
      toset(aws_redshiftserverless_namespace.analytics.iam_roles) == toset([var.redshift_role_arn]) &&
      toset(aws_redshiftserverless_namespace.analytics.log_exports) == toset(["connectionlog", "useractivitylog", "userlog"])
    )
    error_message = "The namespace must use IAM-only access, the exact runtime role, and all audit logs."
  }

  assert {
    condition = (
      !aws_redshiftserverless_workgroup.analytics.publicly_accessible &&
      aws_redshiftserverless_workgroup.analytics.enhanced_vpc_routing &&
      aws_redshiftserverless_workgroup.analytics.base_capacity == 4 &&
      aws_redshiftserverless_workgroup.analytics.max_capacity == 4 &&
      aws_redshiftserverless_workgroup.analytics.port == 5439 &&
      length(aws_redshiftserverless_workgroup.analytics.subnet_ids) == 3 &&
      !one(aws_redshiftserverless_workgroup.analytics.price_performance_target).enabled
    )
    error_message = "Redshift must remain private, cap at 4 RPU, and disable billable AI-driven scaling."
  }

  assert {
    condition = anytrue([
      for parameter in aws_redshiftserverless_workgroup.analytics.config_parameter :
      parameter.parameter_key == "require_ssl" && parameter.parameter_value == "true"
    ])
    error_message = "Redshift must reject non-TLS database connections."
  }

  assert {
    condition = (
      aws_redshiftserverless_usage_limit.compute.amount == 16 &&
      aws_redshiftserverless_usage_limit.compute.breach_action == "deactivate" &&
      aws_redshiftserverless_usage_limit.compute.period == "monthly" &&
      aws_redshiftserverless_usage_limit.compute.usage_type == "serverless-compute"
    )
    error_message = "Redshift compute must hard-stop at the configurable monthly RPU-hour limit."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.redshift) == 3
    error_message = "All Redshift audit log groups must have finite Terraform-managed retention."
  }
}

run "rejects_duplicate_availability_zones" {
  command = plan

  variables {
    availability_zones = ["us-east-2a", "us-east-2a", "us-east-2c"]
  }

  expect_failures = [var.availability_zones]
}

run "rejects_non_integer_usage_limit" {
  command = plan

  variables {
    monthly_rpu_hours = 16.5
  }

  expect_failures = [var.monthly_rpu_hours]
}
