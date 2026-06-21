# Purpose: Identity-joined premium Azure Files storage for FSLogix profile containers.
# Section: PROMPT.md §6 — FSLogix profile storage
# Last updated: 2026-06-10
#
# AVM: avm-res-storage-storageaccount 0.7.2 (uses parent_id; Azure Files auth via directory_type).

locals {
  # AVM storage uses the v2 diagnostic interface — `logs`/`metrics` default to EMPTY (unlike the v1
  # interface used by KV/automation), so categories must be set explicitly or nothing is collected.
  # Static keys so for_each keys are known at plan even when the workspace id isn't yet (greenfield).
  diag_account = {
    to_law = {
      name                  = "diag-to-law"
      workspace_resource_id = var.log_analytics_workspace_resource_id
      metrics               = [{ category = "AllMetrics" }] # account level exposes metrics only
    }
  }
  diag_file = {
    to_law = {
      name                  = "diag-to-law"
      workspace_resource_id = var.log_analytics_workspace_resource_id
      logs                  = [{ category_group = "allLogs" }] # StorageRead/Write/Delete
      metrics               = [{ category = "Transaction" }]
    }
  }
}

module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.7.2"

  name      = var.storage_account_name
  location  = var.location
  parent_id = var.resource_group_resource_id
  tags      = var.tags

  # Premium FileStorage for FSLogix profile containers (IOPS scale with provisioned size).
  # NOTE: in AVM 0.7.2, account_sku_name (default Standard_ZRS) wins via coalesce() over the deprecated
  # account_tier/account_replication_type inputs — so the SKU MUST be set explicitly here.
  account_kind     = "FileStorage"
  account_sku_name = "Premium_${var.account_replication_type}"

  # Private-only, identity-based auth — no public access, no shared keys.
  public_network_access_enabled = false
  shared_access_key_enabled     = false

  network_rules = {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  # Entra Kerberos (AADKERB) for Entra-ID-joined session hosts (value from the identity module).
  azure_files_authentication = {
    directory_type = var.directory_type
  }

  shares = {
    fslogix = {
      name  = "fslogix"
      quota = var.fslogix_share_quota_gb
    }
  }

  # Private endpoint to the file sub-resource, wired to the privatelink.file DNS zone (from the root).
  private_endpoints = {
    file = {
      subnet_resource_id            = var.private_endpoint_subnet_resource_id
      subresource_name              = "file"
      private_dns_zone_resource_ids = [var.file_private_dns_zone_resource_id]
    }
  }

  # Storage diagnostics → Log Analytics (account-level metrics + file-service logs/metrics for FSLogix).
  diagnostic_settings_storage_account = local.diag_account
  diagnostic_settings_file            = local.diag_file
}
