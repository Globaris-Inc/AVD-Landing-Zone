# Purpose: Provider requirements for the networking module.
# Section: PROMPT.md §4 — Networking (spoke)
# Last updated: 2026-06-10
#
# Versions mirror the AVM child modules' published requirements (confirmed on the Terraform Registry):
#   avm-res-network-virtualnetwork 0.17.1, -networksecuritygroup 0.5.1,
#   -applicationsecuritygroup 0.1.1, -routetable 0.5.0.
# These AVM modules pull in azapi/modtm/random; the root module configures azurerm + azapi.

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
