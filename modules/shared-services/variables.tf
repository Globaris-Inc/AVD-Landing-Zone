# Purpose: Inputs for the shared-services module (Compute Gallery + Automation account).
# Section: PROMPT.md §11 — Shared services
# Last updated: 2026-06-12

variable "name_prefix" {
  description = "Naming token, e.g. avd-dev-eus2."
  type        = string
}

variable "location" {
  description = "Azure region for the shared-services resources."
  type        = string
}

variable "resource_group_name" {
  description = "Shared-services resource group name."
  type        = string
}

variable "tags" {
  description = "Tags applied to the shared-services resources."
  type        = map(string)
  default     = {}
}

variable "automation_sku" {
  description = "Automation account SKU (Basic or Free)."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Free"], var.automation_sku)
    error_message = "automation_sku must be Basic or Free."
  }
}

variable "log_analytics_workspace_resource_id" {
  description = "Log Analytics workspace resource ID for Automation diagnostics (§10). Empty disables diagnostics."
  type        = string
  default     = ""
}
