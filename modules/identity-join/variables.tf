# Purpose: Inputs for the identity-join config module.
# Section: PROMPT.md §5 — Identity & domain join
# Last updated: 2026-06-10

variable "identity_mode" {
  description = "Session-host identity model. 'entra-id-join' is the baseline (ADR-0003)."
  type        = string
  default     = "entra-id-join"

  validation {
    condition     = contains(["entra-id-join", "entra-ds", "ad-ds"], var.identity_mode)
    error_message = "identity_mode must be one of: entra-id-join, entra-ds, ad-ds."
  }
}

# The following apply only to the domain-join modes (entra-ds / ad-ds). The domain itself is provided
# by the platform identity subscription (a prerequisite) — this module does NOT deploy domain controllers.

variable "domain_fqdn" {
  description = "AD/Entra-DS domain FQDN to join (e.g. corp.contoso.com). Required for entra-ds / ad-ds; ignored for entra-id-join."
  type        = string
  default     = ""
}

variable "domain_ou_path" {
  description = "Optional OU distinguished name for the session-host computer objects (entra-ds / ad-ds)."
  type        = string
  default     = ""
}
