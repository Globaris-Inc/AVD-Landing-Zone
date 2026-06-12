# Purpose: Outputs from the monitoring module (consumed by diagnostic settings + session-host AMA/DCR).
# Section: PROMPT.md §10 — Monitoring (AVD Insights)
# Last updated: 2026-06-11

output "log_analytics_workspace_resource_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = module.law.resource_id
}

output "data_collection_rule_resource_id" {
  description = "Resource ID of the AVD data collection rule."
  value       = module.dcr.resource_id
}
