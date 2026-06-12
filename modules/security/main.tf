# Purpose: AVD workload Key Vault (RBAC, private, purge-protected) for secrets/keys/certs.
# Section: PROMPT.md §7 — Security (Key Vault, private endpoints, DNS)
# Last updated: 2026-06-11
#
# AVM: avm-res-keyvault-vault 0.10.2. RBAC is the default (legacy_access_policies_enabled = false).

module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name
  tags                = var.tags

  purge_protection_enabled = true

  # Private-only access.
  public_network_access_enabled = false
  network_acls = {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  # Private endpoint to the (implied) vault sub-resource, wired to the vaultcore DNS zone (from the root).
  private_endpoints = {
    vault = {
      subnet_resource_id            = var.private_endpoint_subnet_resource_id
      private_dns_zone_resource_ids = [var.vault_private_dns_zone_resource_id]
    }
  }
}
