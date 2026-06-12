# Purpose: Outputs from the shared-services module.
# Section: PROMPT.md §11 — Shared services
# Last updated: 2026-06-12

output "compute_gallery_resource_id" {
  description = "Resource ID of the Azure Compute Gallery."
  value       = module.compute_gallery.resource_id
}

output "automation_account_resource_id" {
  description = "Resource ID of the Automation account."
  value       = module.automation_account.resource_id
}
