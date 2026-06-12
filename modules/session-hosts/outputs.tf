# Purpose: Outputs from the session-hosts module.
# Section: PROMPT.md §9 — Session hosts
# Last updated: 2026-06-11

output "session_host_resource_ids" {
  description = "Map of session-host VM resource IDs, keyed by index."
  value       = { for k, m in module.session_host : k => m.resource_id }
}

output "session_host_count" {
  description = "Number of session hosts deployed."
  value       = length(module.session_host)
}
