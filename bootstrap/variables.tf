# Purpose: Input variables for the bootstrap layer.
# Section: PROMPT.md §2 — Bootstrap (OIDC, state backend, providers)
# Last updated: 2026-06-10

variable "tenant_id" {
  description = "Microsoft Entra tenant ID. Used by the azuread provider and Key Vault configuration."
  type        = string
}

variable "subscription_id" {
  description = "AVD workload subscription ID. The state backend (RG, Key Vault, Storage Account) is created here, and (when create_oidc_identity = true) the CI principal is granted Contributor + User Access Administrator on it."
  type        = string
}

variable "create_oidc_identity" {
  description = "Create a new OIDC app registration + service principal + federated credentials + subscription RBAC for GitHub Actions CI. Set false to reuse an existing app registration (then wire its RBAC/federated credentials separately) — bootstrap becomes state-backend-only."
  type        = bool
  default     = true
}

variable "shared_services_subscription_id" {
  description = "Optional AVD shared-services subscription ID. When set, the CI principal is also granted Owner on it. Leave empty for a single-subscription deployment."
  type        = string
  default     = ""
}

variable "workload" {
  description = "Short workload token used in resource names (lowercase, no spaces, max 8 chars)."
  type        = string
  default     = "avd"

  validation {
    condition     = can(regex("^[a-z0-9]{1,8}$", var.workload))
    error_message = "workload must be lowercase alphanumeric and at most 8 characters."
  }
}

variable "primary_location" {
  description = "Primary Azure region for the bootstrap (state backend) resources."
  type        = string
  default     = "eastus2"
}

variable "github_org" {
  description = "GitHub organisation or user that owns the repository. Used to build the OIDC federated-credential subjects. Required only when create_oidc_identity = true."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix). Used to build the OIDC federated-credential subjects. Required only when create_oidc_identity = true."
  type        = string
  default     = ""
}

variable "ip_allow_list" {
  description = <<-EOT
    Public IPs/CIDRs permitted to reach the state Storage Account over public network
    (temporary until the security section adds a Private Endpoint). Include your deployer IP
    and the GitHub Actions runner ranges.
      Deployer IP:    curl -s https://api.ipify.org
      Actions ranges: curl -s https://api.github.com/meta | jq '.actions[]'
  EOT
  type        = list(string)

  validation {
    condition     = length(var.ip_allow_list) > 0
    error_message = "ip_allow_list must contain at least one IP address or CIDR block."
  }
}

variable "kv_soft_delete_retention_days" {
  description = "Days to retain soft-deleted Key Vault objects (7–90)."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags merged onto all bootstrap resources. Common tags are always applied."
  type        = map(string)
  default     = {}
}
