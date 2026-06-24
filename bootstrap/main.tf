# Purpose: Remote-state backend — Resource Group, Key Vault (CMK), Storage Account.
# Section: PROMPT.md §2 — Bootstrap (OIDC, state backend, providers)
# Last updated: 2026-06-10
#
# Resources created (in the AVD workload subscription):
#   - Resource Group
#   - User-Assigned Managed Identity (for Storage CMK)
#   - Key Vault (RBAC auth, soft-delete, purge protection) + RSA-2048 CMK key
#   - Storage Account (Standard GZRS, CMK, versioning, Entra-ID-only auth) + 'tfstate' container
#   - Role assignments: deployer -> KV Crypto Officer; UAMI -> KV Crypto Encryption User;
#     deployer -> Storage Blob Data Contributor (RG scope, for state data-plane access)
#
# DEVIATION: the state Storage Account is reachable from var.ip_allow_list (deployer + GitHub Actions
# runners) over public network with default_action = "Deny". This IP allow-list is the PERMANENT posture
# for the bootstrap state account — a private endpoint would need a spoke VNet, which is created by the
# very state this account stores (chicken-and-egg). Keep the deny + allow-list.

locals {
  common_tags = merge(
    {
      workload           = var.workload
      environment        = "shared"
      managedBy          = "iac-terraform"
      owner              = "platform-team"
      costCenter         = "platform"
      criticality        = "high"
      dataClassification = "confidential"
      purpose            = "tfstate-backend"
    },
    var.tags
  )

  # Both Key Vault network_acls AND Storage network_rules reject /31 and /32 suffixes — they accept bare
  # IPs (or /0–/30 CIDRs). Strip a /32 from each entry so a single-IP allow-list works for both.
  ip_rules = [for ip in var.ip_allow_list : trimsuffix(ip, "/32")]

  # Deterministic name suffix (ADR-0008): a function of the subscription ID, NOT random_string.
  # The subscription ID is the same on every re-bootstrap, so the state Storage Account and Key Vault
  # names are reproducible — envs/*.backend.hcl stays valid across teardown/rebuild cycles without
  # hand-editing. var.subscription_id is lowercased before hashing so the value matches the precomputed
  # hcl values (the live ID is already lowercase). 8 lowercase hex chars. SHA1 is used purely to shorten
  # a name, not for any security property.
  suffix = substr(sha1(lower(var.subscription_id)), 0, 8)
}

data "azurerm_client_config" "current" {}

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
  name                = "kv-tfstate-${local.suffix}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  soft_delete_retention_days = var.kv_soft_delete_retention_days
  purge_protection_enabled   = true

  # Public endpoint stays enabled (Storage reaches the KV via trusted services for the CMK), but
  # access is restricted to the deployer/runner IPs — not the whole internet.
  public_network_access_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = local.ip_rules
  }

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
# Storage data-plane RBAC for the deployer (the principal running Terraform).
# Scoped at the RG so it exists BEFORE the account: with shared keys disabled the provider polls the
# new account's blob service over Entra (storage_use_azuread), which 403s without this role. The CI
# principal (the same service principal) reuses this role to read/write remote state.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "deployer_storage_blob" {
  scope                = azurerm_resource_group.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_storage_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_storage_blob]
  create_duration = "60s"
}

# ---------------------------------------------------------------------------
# Storage Account (Standard GZRS, CMK, versioning, Entra-ID-only auth)
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "tfstate" {
  name                     = "sttfstate${local.suffix}"
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

  # DEVIATION: public access restricted to the deployer/runner IPs — permanent for the bootstrap state SA (see header).
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = local.ip_rules
  }

  tags = local.common_tags

  # The blob-service availability poll after creation uses Entra (storage_use_azuread) and needs the
  # deployer's data-plane role to be in place and propagated first.
  depends_on = [time_sleep.wait_for_storage_rbac]

  lifecycle {
    # CMK is managed by the separate azurerm_storage_account_customer_managed_key resource below.
    # Without this, the SA resource perpetually tries to null out the customer_managed_key block
    # (provider quirk) and would flip the account back to Microsoft-managed keys on every apply.
    ignore_changes = [customer_managed_key]
  }
}

resource "azurerm_storage_account_customer_managed_key" "tfstate" {
  storage_account_id        = azurerm_storage_account.tfstate.id
  key_vault_id              = azurerm_key_vault.tfstate.id
  key_name                  = azurerm_key_vault_key.tfstate.name
  user_assigned_identity_id = azurerm_user_assigned_identity.tfstate.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

# ---------------------------------------------------------------------------
# State container (no WORM — see NOTE below; versioning provides state recovery)
# ---------------------------------------------------------------------------

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# NOTE: deliberately NO immutability/WORM policy on the state container. A time-based immutability
# policy enforces write-once even while "unlocked", which blocks Terraform's per-apply state overwrites
# and locks (409 BlobImmutableDueToPolicy). Blob versioning (enabled above) provides state history and
# point-in-time recovery instead.
