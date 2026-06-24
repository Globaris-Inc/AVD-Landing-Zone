# Purpose: Provider and Terraform version constraints for the bootstrap layer.
# Section: PROMPT.md §2 — Bootstrap (OIDC, state backend, providers)
# Last updated: 2026-06-10
#
# This root module uses LOCAL state (DECISIONS.md ADR-0002): it creates the remote-state
# backend, so it cannot itself depend on it. Run once, manually:
#   terraform init && terraform apply -var-file=terraform.tfvars
# After apply, paste the outputs into envs/<env>.backend.hcl and the GitHub repo variables.
#
# Versions mirror the validated sibling repo (Azure-Architecture). Confirm/bump against the
# Terraform Registry before a production run.

terraform {
  required_version = ">= 1.10" # align with the workload root + AVM floor (bootstrap itself is native azurerm)

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.71.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  # The state Storage Account disables shared keys (Entra-ID/RBAC only). Without this the provider
  # falls back to shared-key auth for the blob data plane and fails with KeyBasedAuthenticationNotPermitted.
  storage_use_azuread = true

  features {
    key_vault {
      # Never auto-purge on destroy — purge protection is enabled on the bootstrap KV.
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
  tenant_id = var.tenant_id
}
