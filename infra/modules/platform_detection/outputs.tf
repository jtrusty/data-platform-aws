output "guardduty_detector_id" {
  description = "GuardDuty detector protecting this account."
  value       = aws_guardduty_detector.platform.id
}

output "config_recorder_name" {
  description = "AWS Config configuration recorder name."
  value       = aws_config_configuration_recorder.platform.name
}

output "config_resource_types" {
  description = "Resource types AWS Config records; a bounded list keeps configuration-item charges predictable."
  value       = var.config_resource_types
}

output "security_hub_enabled" {
  description = "Whether Security Hub and the foundational standard are enabled."
  value       = var.enable_security_hub
}

output "flow_log_id" {
  description = "VPC flow log recording analytics network traffic."
  value       = aws_flow_log.analytics.id
}
