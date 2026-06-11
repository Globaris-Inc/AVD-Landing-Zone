# Purpose: Outputs from the FSLogix storage module (consumed by session hosts §9).
# Section: PROMPT.md §6 — FSLogix profile storage
# Last updated: 2026-06-10

output "storage_account_resource_id" {
  description = "Resource ID of the FSLogix storage account."
  value       = module.storage_account.resource_id
}

output "storage_account_name" {
  description = "Name of the FSLogix storage account."
  value       = module.storage_account.name
}

output "fslogix_share_name" {
  description = "Name of the FSLogix profile file share."
  value       = "fslogix"
}

output "fslogix_share_unc_path" {
  description = "UNC path to the FSLogix share (configure on session hosts)."
  value       = "\\\\${module.storage_account.name}.file.core.windows.net\\fslogix"
}
