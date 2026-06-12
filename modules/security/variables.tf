# Purpose: Inputs for the security module (AVD workload Key Vault).
# Section: PROMPT.md §7 — Security (Key Vault, private endpoints, DNS)
# Last updated: 2026-06-11

variable "key_vault_name" {
  description = "Key Vault name (3-24 chars, alphanumeric + dashes, globally unique). Computed by the caller."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "key_vault_name must be 3-24 chars, start with a letter, end alphanumeric, dashes allowed."
  }
}

variable "location" {
  description = "Azure region for the Key Vault."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group NAME for the Key Vault (this AVM module uses resource_group_name, not parent_id)."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID for the Key Vault."
  type        = string
}

variable "sku_name" {
  description = "Key Vault SKU (standard or premium)."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be standard or premium."
  }
}

variable "tags" {
  description = "Tags applied to the Key Vault."
  type        = map(string)
  default     = {}
}

variable "private_endpoint_subnet_resource_id" {
  description = "Subnet resource ID for the Key Vault private endpoint."
  type        = string
}

variable "vault_private_dns_zone_resource_id" {
  description = "privatelink.vaultcore.azure.net private DNS zone resource ID to wire the private endpoint to."
  type        = string
}
