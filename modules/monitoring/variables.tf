# Purpose: Inputs for the monitoring module (Log Analytics workspace + AVD data collection rule).
# Section: PROMPT.md §10 — Monitoring (AVD Insights)
# Last updated: 2026-06-11

variable "name_prefix" {
  description = "Naming token, e.g. avd-dev-eus2."
  type        = string
}

variable "location" {
  description = "Azure region for the monitoring resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group NAME for the Log Analytics workspace."
  type        = string
}

variable "resource_group_resource_id" {
  description = "Resource group RESOURCE ID — the data collection rule's parent_id."
  type        = string
}

variable "tags" {
  description = "Tags applied to the monitoring resources."
  type        = map(string)
  default     = {}
}

variable "retention_in_days" {
  description = "Log Analytics data retention in days (30-730)."
  type        = number
  default     = 30
}

variable "law_sku" {
  description = "Log Analytics workspace SKU."
  type        = string
  default     = "PerGB2018"
}
