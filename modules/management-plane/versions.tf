# Purpose: Provider requirements for the management-plane module.
# Section: PROMPT.md §8 — Management plane
# Last updated: 2026-06-11
#
# Mirrors the AVM desktop-virtualization modules' provider requirements (confirmed on the Registry):
#   hostpool 0.4.0, applicationgroup 0.2.1, workspace 0.2.2, scalingplan 0.2.1.

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
