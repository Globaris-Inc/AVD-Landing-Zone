# Purpose: Outputs from the AVD workload composition root.
# Section: PROMPT.md §3 — Resource organization, naming & tagging
# Last updated: 2026-06-10

output "resource_group_names" {
  description = "Map of AVD resource group names, keyed by role (workload, shared)."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.name }
}

output "resource_group_ids" {
  description = "Map of AVD resource group resource IDs, keyed by role (workload, shared)."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.id }
}

output "location" {
  description = "Primary Azure region for the AVD workload."
  value       = var.location
}

output "naming" {
  description = "Naming context (prefix + tokens) for downstream consumers."
  value       = local.naming
}

# Networking (null when deploy_networking = false)
output "virtual_network_resource_id" {
  description = "Spoke VNet resource ID, or null when networking is not deployed here."
  value       = try(local.networking.virtual_network_resource_id, null)
}

output "session_host_subnet_resource_id" {
  description = "Session-host subnet resource ID, or null when networking is not deployed here."
  value       = try(local.networking.session_host_subnet_resource_id, null)
}

output "private_endpoint_subnet_resource_id" {
  description = "Private-endpoint subnet resource ID, or null when networking is not deployed here."
  value       = try(local.networking.private_endpoint_subnet_resource_id, null)
}

output "identity_mode" {
  description = "Selected session-host identity model."
  value       = module.identity_join.identity_mode
}
