# Purpose: Normalised identity configuration consumed by the storage (§6) and session-host (§9) sections.
# Section: PROMPT.md §5 — Identity & domain join
# Last updated: 2026-06-10

output "identity_mode" {
  description = "The selected identity model."
  value       = var.identity_mode
}

output "entra_id_join" {
  description = "True when session hosts join Microsoft Entra ID directly (AADLoginForWindows)."
  value       = local.is_entra_id_join
}

output "azure_files_directory_service_options" {
  description = "directory_service_options for the FSLogix Azure Files storage account (AADKERB / AADDS / AD)."
  value       = local.azure_files_directory_service_options
}

output "domain_join" {
  description = "Domain-join config { fqdn, ou_path } for session hosts, or null for Entra ID join."
  value       = local.domain_join

  precondition {
    condition     = !local.is_domain_join || var.domain_fqdn != ""
    error_message = "domain_fqdn must be set when identity_mode is entra-ds or ad-ds."
  }
}
