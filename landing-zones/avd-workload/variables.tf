# Purpose: Input variables for the AVD workload composition root.
# Section: PROMPT.md §3 — Resource organization, naming & tagging
# Last updated: 2026-06-10
#
# Later sections add their own variables to this file as modules are wired in.

# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "AVD workload subscription ID. Both the workload and shared-services resource groups are created here (single-subscription model; see ARCHITECTURE.md for the multi-subscription option)."
  type        = string
}

variable "location" {
  description = "Primary Azure region for AVD resources (e.g. eastus2)."
  type        = string
}

variable "location_short" {
  description = "Short region token used in resource names (e.g. eus2 for East US 2)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.location_short))
    error_message = "location_short must be 2–6 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment / lifecycle stage."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "workload" {
  description = "Short workload token used in resource names and tags."
  type        = string
  default     = "avd"

  validation {
    condition     = can(regex("^[a-z0-9]{1,8}$", var.workload))
    error_message = "workload must be lowercase alphanumeric and at most 8 characters."
  }
}

# ---------------------------------------------------------------------------
# Tagging inputs (consumed by local.common_tags — see locals.tf)
# ---------------------------------------------------------------------------

variable "owner" {
  description = "Team or DRI responsible for the workload (email or team name)."
  type        = string
}

variable "cost_center" {
  description = "Cost-center / chargeback code."
  type        = string
}

variable "criticality" {
  description = "Business-impact classification."
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["low", "medium", "high"], var.criticality)
    error_message = "criticality must be one of: low, medium, high."
  }
}

variable "data_classification" {
  description = "Data sensitivity classification."
  type        = string
  default     = "confidential"
}

variable "tags" {
  description = "Additional tags merged onto all resources. Common tags are always applied (see locals.tf)."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Networking (Section 4)
# ---------------------------------------------------------------------------

variable "deploy_networking" {
  description = "Deploy a new spoke VNet (with NSG/ASG/route table). When false, later sections must be given existing subnet IDs."
  type        = bool
  default     = true
}

variable "vnet_address_space" {
  description = "Spoke VNet address space (CIDR list). Used when deploy_networking = true."
  type        = list(string)
  default     = ["10.20.0.0/24"]
}

variable "session_host_subnet_prefix" {
  description = "CIDR for the session-host subnet."
  type        = string
  default     = "10.20.0.0/25"
}

variable "private_endpoint_subnet_prefix" {
  description = "CIDR for the private-endpoint subnet."
  type        = string
  default     = "10.20.0.128/26"
}

variable "hub_vnet_resource_id" {
  description = "Optional platform hub VNet resource ID to peer the spoke with. Empty disables peering."
  type        = string
  default     = ""
}

variable "firewall_private_ip" {
  description = "Optional platform firewall private IP for the default egress route. Empty omits the route."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Identity (Section 5) — see ADR-0003
# ---------------------------------------------------------------------------

variable "identity_mode" {
  description = "Session-host identity model: entra-id-join (baseline), entra-ds, or ad-ds."
  type        = string
  default     = "entra-id-join"

  validation {
    condition     = contains(["entra-id-join", "entra-ds", "ad-ds"], var.identity_mode)
    error_message = "identity_mode must be one of: entra-id-join, entra-ds, ad-ds."
  }
}

variable "domain_fqdn" {
  description = "Domain FQDN to join (only for entra-ds / ad-ds). Ignored for entra-id-join."
  type        = string
  default     = ""
}

variable "domain_ou_path" {
  description = "Optional OU for session-host computer objects (entra-ds / ad-ds)."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# FSLogix storage (Section 6)
# ---------------------------------------------------------------------------

variable "fslogix_share_quota_gb" {
  description = "FSLogix profile share quota in GiB. Premium FileStorage requires greater than 100."
  type        = number
  default     = 128

  validation {
    condition     = var.fslogix_share_quota_gb > 100
    error_message = "fslogix_share_quota_gb must be greater than 100 (Premium FileStorage minimum)."
  }
}

variable "fslogix_account_replication_type" {
  description = "Replication for the premium FileStorage account (LRS or ZRS)."
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "ZRS"], var.fslogix_account_replication_type)
    error_message = "fslogix_account_replication_type must be LRS or ZRS."
  }
}

variable "file_private_dns_zone_name" {
  description = "Private DNS zone name for Azure Files private endpoints."
  type        = string
  default     = "privatelink.file.core.windows.net"
}

# ---------------------------------------------------------------------------
# Security (Section 7)
# ---------------------------------------------------------------------------

variable "tenant_id" {
  description = "Microsoft Entra tenant ID (used by the Key Vault)."
  type        = string
}

variable "key_vault_sku" {
  description = "Key Vault SKU (standard or premium)."
  type        = string
  default     = "standard"
}

variable "vault_private_dns_zone_name" {
  description = "Private DNS zone name for Key Vault private endpoints."
  type        = string
  default     = "privatelink.vaultcore.azure.net"
}

# ---------------------------------------------------------------------------
# Management plane (Section 8)
# ---------------------------------------------------------------------------

variable "host_pool_type" {
  description = "AVD host pool type: Pooled or Personal."
  type        = string
  default     = "Pooled"
}

variable "max_sessions_allowed" {
  description = "Maximum sessions per host (Pooled host pools)."
  type        = number
  default     = 8
}

variable "app_group_type" {
  description = "Application group type: Desktop or RemoteApp."
  type        = string
  default     = "Desktop"
}

variable "deploy_scaling_plan" {
  description = "Deploy an autoscale scaling plan (Pooled host pools only)."
  type        = bool
  default     = true
}

variable "scaling_plan_time_zone" {
  description = "Time zone for the scaling plan schedule."
  type        = string
  default     = "UTC"
}
