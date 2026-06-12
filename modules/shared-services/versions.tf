# Purpose: Provider requirements for the shared-services module.
# Section: PROMPT.md §11 — Shared services
# Last updated: 2026-06-12
#
# Mirrors AVM compute-gallery 0.2.0 + automation-automationaccount 0.2.0 provider requirements.

terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
