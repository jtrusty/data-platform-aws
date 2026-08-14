variable "alert_email" {
  description = "Address subscribed to management-account budget alerts. Supplied through a gitignored tfvars file; never committed to this public repository."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for the management account."
  type        = number
  default     = 25
}

variable "enable_security_hub" {
  description = "Enable Security Hub in the management account. Off until a measured bill justifies the per-check charge."
  type        = bool
  default     = false
}
