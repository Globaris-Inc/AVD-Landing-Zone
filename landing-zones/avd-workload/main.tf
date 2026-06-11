# Purpose: AVD workload + shared-services resource groups (composition root entrypoint).
# Section: PROMPT.md §3 — Resource organization, naming & tagging
# Last updated: 2026-06-10
#
# Later sections add module blocks here, deploying into these resource groups.
# Single-subscription model: both RGs are created in var.subscription_id (see ARCHITECTURE.md
# for the separate shared-services subscription option, which would use a provider alias).

resource "azurerm_resource_group" "this" {
  for_each = local.resource_group_names

  name     = each.value
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# Networking (PROMPT.md §4) — optional spoke, deployed into the workload RG.
# for_each (not count) keeps the conditional resource address stable.
# ---------------------------------------------------------------------------
module "networking" {
  source   = "../../modules/networking"
  for_each = var.deploy_networking ? toset(["this"]) : toset([])

  name_prefix                    = local.name_prefix
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this["workload"].name
  resource_group_resource_id     = azurerm_resource_group.this["workload"].id
  tags                           = local.common_tags
  address_space                  = var.vnet_address_space
  session_host_subnet_prefix     = var.session_host_subnet_prefix
  private_endpoint_subnet_prefix = var.private_endpoint_subnet_prefix
  hub_vnet_resource_id           = var.hub_vnet_resource_id
  firewall_private_ip            = var.firewall_private_ip
}

locals {
  # The single networking instance (or null when deploy_networking = false), so
  # later sections can read subnet IDs via local.networking.<output>.
  networking = one(values(module.networking))
}

# ---------------------------------------------------------------------------
# Identity (PROMPT.md §5) — normalises identity_mode into config for §6/§9.
# ---------------------------------------------------------------------------
module "identity_join" {
  source = "../../modules/identity-join"

  identity_mode  = var.identity_mode
  domain_fqdn    = var.domain_fqdn
  domain_ou_path = var.domain_ou_path
}

locals {
  # Identity config consumed downstream: local.identity.azure_files_directory_service_options (§6),
  # local.identity.entra_id_join + local.identity.domain_join (§9).
  identity = module.identity_join
}
