# Purpose: Bootstrap outputs — paste into envs/<env>.backend.hcl and the GitHub repo variables.
# Section: PROMPT.md §2 — Bootstrap (OIDC, state backend, providers)
# Last updated: 2026-06-10

# ---------------------------------------------------------------------------
# State backend — paste into envs/<env>.backend.hcl
# ---------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group hosting the Terraform state backend. -> envs/<env>.backend.hcl: resource_group_name"
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Terraform state Storage Account name. -> envs/<env>.backend.hcl: storage_account_name"
  value       = azurerm_storage_account.tfstate.name
}

output "storage_container_name" {
  description = "Terraform state container (always 'tfstate'). -> envs/<env>.backend.hcl: container_name"
  value       = azurerm_storage_container.tfstate.name
}

output "key_vault_name" {
  description = "Bootstrap Key Vault holding the state-SA CMK."
  value       = azurerm_key_vault.tfstate.name
}

output "key_vault_id" {
  description = "Resource ID of the bootstrap Key Vault."
  value       = azurerm_key_vault.tfstate.id
}

# ---------------------------------------------------------------------------
# OIDC / GitHub Actions — set as GitHub repository VARIABLES (not secrets)
# ---------------------------------------------------------------------------

output "oidc_client_id" {
  description = "Application (client) ID of the OIDC app registration. -> GitHub repo variable AZURE_CLIENT_ID"
  value       = azuread_application.oidc.client_id
}

output "oidc_tenant_id" {
  description = "Entra tenant ID. -> GitHub repo variable AZURE_TENANT_ID"
  value       = var.tenant_id
}

output "oidc_sp_object_id" {
  description = "Object ID of the OIDC service principal (useful for auditing role assignments)."
  value       = azuread_service_principal.oidc.object_id
}

output "subscription_id" {
  description = "AVD workload subscription ID. -> GitHub repo variable AZURE_SUBSCRIPTION_ID"
  value       = var.subscription_id
}
