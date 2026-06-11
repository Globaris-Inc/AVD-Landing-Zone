# Purpose: Normalise the identity model into configuration for downstream sections.
# Section: PROMPT.md §5 — Identity & domain join
# Last updated: 2026-06-10
#
# No resources — only locals. For entra-id-join the outputs are flags + the Azure Files auth mode.
# For entra-ds / ad-ds the outputs add the domain-join config pointing at the platform-provided domain.

locals {
  is_entra_id_join = var.identity_mode == "entra-id-join"
  is_domain_join   = contains(["entra-ds", "ad-ds"], var.identity_mode)

  # FSLogix Azure Files identity-based authentication mode per identity model (§6 consumes this).
  azure_files_directory_service_options = {
    "entra-id-join" = "AADKERB"
    "entra-ds"      = "AADDS"
    "ad-ds"         = "AD"
  }[var.identity_mode]

  # Domain-join config for session hosts (null for Entra ID join; §9 consumes this).
  domain_join = local.is_domain_join ? {
    fqdn    = var.domain_fqdn
    ou_path = var.domain_ou_path
  } : null
}
