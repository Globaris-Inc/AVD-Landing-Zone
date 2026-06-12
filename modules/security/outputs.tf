# Purpose: Outputs from the security module.
# Section: PROMPT.md §7 — Security (Key Vault, private endpoints, DNS)
# Last updated: 2026-06-11

output "key_vault_resource_id" {
  description = "Resource ID of the Key Vault."
  value       = module.key_vault.resource_id
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = module.key_vault.uri
}
