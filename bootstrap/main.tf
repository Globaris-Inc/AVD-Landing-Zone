# Purpose: Remote-state backend — Resource Group, Key Vault (CMK), Storage Account.
# Section: PROMPT.md §2 — Bootstrap (OIDC, state backend, providers)
# Last updated: 2026-06-10
#
# Resources created (in the AVD workload subscription):
#   - Resource Group
#   - User-Assigned Managed Identity (for Storage CMK)
#   - Key Vault (RBAC auth, soft-delete, purge protection) + RSA-2048 CMK key
#   - Storage Account (Standard GZRS, CMK, versioning, Entra-ID-only auth) + 'tfstate' container
#   - Container immutability policy (unlocked WORM demonstration)
#   - Role assignments: deployer -> KV Crypto Officer; UAMI -> KV Crypto Encryption User
#
# DEVIATION: Storage Account allows public access from var.ip_allow_list (deployer + GitHub
# Actions runners). The security section (PROMPT.md §7) adds a Private Endpoint and removes the
# IP rules. Until then the account stays default_action = "Deny" with an explicit allow-list.
#
# DEVIATION: Immutability policy is set with locked = false — a locked policy blocks blob
# overwrites and would break active Terraform state writes. Flip to locked = true only on a
# decommissioned/archived state container.

locals {
  common_tags = merge(
    {
      workload    = var.workload
      environment = "shared"
      managedBy   = "iac-terraform"
      owner       = "platform-team"
      costCenter  = "platform"
      criticality = "high"
      purpose     = "tfstate-backend"
    },
    var.tags
  )
}

data "azurerm_client_config" "current" {}

# Stable unique suffix — changes only if tainted/destroyed.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate-${var.workload}-001"
  location = var.primary_location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# User-Assigned Managed Identity (used by the Storage Account for CMK)
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "tfstate" {
  name                = "id-tfstate-${var.workload}-001"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# Key Vault (RBAC-authorised, soft-delete, purge-protected)
# ---------------------------------------------------------------------------

resource "azurerm_key_vault" "tfstate" {
  name                = "kv-tfstate-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization  = true
  soft_delete_retention_days = var.kv_soft_delete_retention_days
  purge_protection_enabled   = true

  # Public access is acceptable for the bootstrap KV: used only during the one-time apply and
  # internally by the Storage Account (trusted services) to wrap/unwrap the CMK.
  public_network_access_enabled = true

  tags = local.common_tags
}

# Deployer needs Crypto Officer to create the CMK key.
resource "azurerm_role_assignment" "deployer_kv_crypto_officer" {
  scope                = azurerm_key_vault.tfstate.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# UAMI needs Crypto Service Encryption User so the Storage Account can use the CMK.
resource "azurerm_role_assignment" "tfstate_uami_kv_crypto" {
  scope                = azurerm_key_vault.tfstate.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.tfstate.principal_id
}

# Azure RBAC propagation can take 30–60s. Wait before creating the key / storage CMK.
resource "time_sleep" "wait_for_kv_rbac" {
  depends_on = [
    azurerm_role_assignment.deployer_kv_crypto_officer,
    azurerm_role_assignment.tfstate_uami_kv_crypto,
  ]
  create_duration = "60s"
}

# ---------------------------------------------------------------------------
# CMK key
# ---------------------------------------------------------------------------

resource "azurerm_key_vault_key" "tfstate" {
  name         = "key-tfstate-cmk-001"
  key_vault_id = azurerm_key_vault.tfstate.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P1Y"
    notify_before_expiry = "P30D"
  }

  depends_on = [time_sleep.wait_for_kv_rbac]
  tags       = local.common_tags
}

# ---------------------------------------------------------------------------
# Storage Account (Standard GZRS, CMK, versioning, Entra-ID-only auth)
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "tfstate" {
  name                     = "sttfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "GZRS"
  account_kind             = "StorageV2"

  # Entra ID (RBAC) auth only — no shared access keys.
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.tfstate.id]
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }

    container_delete_retention_policy {
      days = 14
    }
  }

  # DEVIATION: temporary public access — see file header. Removed when §7 adds a Private Endpoint.
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.ip_allow_list
  }

  tags = local.common_tags
}

resource "azurerm_storage_account_customer_managed_key" "tfstate" {
  storage_account_id        = azurerm_storage_account.tfstate.id
  key_vault_id              = azurerm_key_vault.tfstate.id
  key_name                  = azurerm_key_vault_key.tfstate.name
  user_assigned_identity_id = azurerm_user_assigned_identity.tfstate.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

# ---------------------------------------------------------------------------
# State container + immutability (unlocked WORM demonstration)
# ---------------------------------------------------------------------------

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# DEVIATION: locked = false — see file header.
resource "azurerm_storage_container_immutability_policy" "tfstate" {
  storage_container_resource_manager_id = azurerm_storage_container.tfstate.resource_manager_id
  immutability_period_in_days           = 7
  locked                                = false
}
