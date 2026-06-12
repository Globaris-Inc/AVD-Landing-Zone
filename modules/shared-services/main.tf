# Purpose: Shared AVD services — Azure Compute Gallery (golden images) + Automation account (runbooks).
# Section: PROMPT.md §11 — Shared services
# Last updated: 2026-06-12
#
# AVM: compute-gallery 0.2.0, automation-automationaccount 0.2.0.

module "compute_gallery" {
  source  = "Azure/avm-res-compute-gallery/azurerm"
  version = "0.2.0"

  # Compute Gallery names allow alphanumerics, underscores and periods — no dashes.
  name                = "gal_${replace(var.name_prefix, "-", "_")}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

module "automation_account" {
  source  = "Azure/avm-res-automation-automationaccount/azurerm"
  version = "0.2.0"

  name                = "aa-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.automation_sku
  tags                = var.tags

  diagnostic_settings = var.log_analytics_workspace_resource_id == "" ? {} : {
    to_law = {
      name                  = "diag-to-law"
      workspace_resource_id = var.log_analytics_workspace_resource_id
    }
  }
}

# NOTE: the AVM compute-gallery 0.2.0 module exposes no diagnostic_settings input — gallery diagnostics
# are not wired (gallery emits little operational telemetry; revisit if a newer module version adds it).
