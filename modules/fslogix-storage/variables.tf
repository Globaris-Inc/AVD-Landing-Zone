# Purpose: Inputs for the FSLogix storage module (identity-joined Azure Files for profiles).
# Section: PROMPT.md §6 — FSLogix profile storage
# Last updated: 2026-06-10

variable "storage_account_name" {
  description = "Globally-unique storage account name (3–24 lowercase alphanumerics). Computed by the caller."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3–24 lowercase alphanumeric characters."
  }
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

variable "resource_group_resource_id" {
  description = "Resource group RESOURCE ID — the storage module's parent_id (/subscriptions/.../resourceGroups/...)."
  type        = string
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}

variable "fslogix_share_quota_gb" {
  description = "FSLogix profile share quota in GiB. Premium FileStorage requires greater than 100."
  type        = number
  default     = 128

  validation {
    condition     = var.fslogix_share_quota_gb > 100
    error_message = "fslogix_share_quota_gb must be greater than 100 (Premium FileStorage minimum)."
  }
}

variable "account_replication_type" {
  description = "Replication for the premium FileStorage account (LRS or ZRS)."
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "ZRS"], var.account_replication_type)
    error_message = "account_replication_type must be LRS or ZRS (premium FileStorage)."
  }
}

variable "directory_type" {
  description = "Azure Files identity-based auth directory type, from the identity module (AADKERB for Entra ID join, AADDS, or AD)."
  type        = string

  validation {
    condition     = contains(["AADKERB", "AADDS", "AD"], var.directory_type)
    error_message = "directory_type must be AADKERB, AADDS, or AD."
  }
}

# NOTE: AD (self-managed AD DS) additionally requires azure_files_authentication.active_directory
# (domain GUID/SID etc.). Out of scope for the entra-id-join baseline (ADR-0003); add when AD is chosen.

variable "private_endpoint_subnet_resource_id" {
  description = "Subnet resource ID for the storage (file) private endpoint."
  type        = string
}

variable "file_private_dns_zone_resource_id" {
  description = "privatelink.file.* private DNS zone resource ID to wire the private endpoint to."
  type        = string
}
