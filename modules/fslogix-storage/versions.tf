# Purpose: Provider requirements for the FSLogix storage module.
# Section: PROMPT.md §6 — FSLogix profile storage
# Last updated: 2026-06-10
#
# Mirrors the AVM storage module's published provider requirements
# (avm-res-storage-storageaccount 0.7.2, confirmed on the Terraform Registry).

terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
