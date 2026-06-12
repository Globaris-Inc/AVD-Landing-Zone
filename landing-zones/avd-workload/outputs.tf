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

output "fslogix_storage_account_name" {
  description = "Name of the FSLogix storage account."
  value       = module.fslogix_storage.storage_account_name
}

output "fslogix_share_unc_path" {
  description = "UNC path to the FSLogix profile share (configure on session hosts)."
  value       = module.fslogix_storage.fslogix_share_unc_path
}

output "key_vault_name" {
  description = "Key Vault name, or null when deploy_networking = false."
  value       = try(module.security["this"].key_vault_name, null)
}

output "key_vault_uri" {
  description = "Key Vault URI, or null when deploy_networking = false."
  value       = try(module.security["this"].key_vault_uri, null)
}

output "host_pool_name" {
  description = "AVD host pool name (session hosts register against it)."
  value       = module.management_plane.host_pool_name
}

output "workspace_resource_id" {
  description = "AVD workspace resource ID."
  value       = module.management_plane.workspace_resource_id
}

output "session_host_count" {
  description = "Number of session hosts deployed (0 when none)."
  value       = try(module.session_hosts["this"].session_host_count, 0)
}

output "log_analytics_workspace_resource_id" {
  description = "Log Analytics workspace resource ID."
  value       = module.monitoring.log_analytics_workspace_resource_id
}
