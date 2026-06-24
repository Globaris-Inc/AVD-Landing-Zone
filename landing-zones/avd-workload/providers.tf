# Purpose: Terraform/provider config + remote-state backend for the AVD workload composition root.
# Section: PROMPT.md §3 — Resource organization, naming & tagging
# Last updated: 2026-06-10
#
# The backend is a PARTIAL config — initialise per environment:
#   terraform init -backend-config=../../envs/dev.backend.hcl
# In CI, set ARM_USE_OIDC=true so the azurerm provider authenticates via GitHub OIDC; locally use `az login`.
# Provider version mirrors the validated sibling repo — confirm/bump on the Registry before apply.

terraform {
  required_version = ">= 1.10" # avm-res-storage-storageaccount / -compute-virtualmachine require >= 1.10

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.71.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}

# Required by the AVM network modules (and other AVM modules that use azapi internally).
provider "azapi" {}
