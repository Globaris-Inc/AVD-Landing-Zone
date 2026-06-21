# Purpose: Outputs from the management-plane module (consumed by session hosts §9).
# Section: PROMPT.md §8 — Management plane
# Last updated: 2026-06-11

output "host_pool_resource_id" {
  description = "Resource ID of the AVD host pool."
  value       = module.host_pool.resource_id
}

output "host_pool_name" {
  description = "Name of the AVD host pool (session hosts register against it)."
  value       = "vdpool-${var.name_prefix}"
}

output "application_group_resource_id" {
  description = "Resource ID of the AVD application group."
  value       = module.application_group.resource_id
}

output "workspace_resource_id" {
  description = "Resource ID of the AVD workspace."
  value       = module.workspace.resource_id.id # AVM workspace 0.2.2 resource_id output is the whole object
}

output "host_pool_registration_token" {
  description = "AVD host pool registration token (sensitive) for session-host agent registration."
  value       = module.host_pool.registrationinfo_token
  sensitive   = true
}
