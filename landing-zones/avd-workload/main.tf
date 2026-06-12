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

# ---------------------------------------------------------------------------
# FSLogix profile storage (PROMPT.md §6) — into the workload RG.
# Baseline assumes deploy_networking = true (consumes the §4 PE subnet + spoke VNet);
# brownfield (existing subnet/zone IDs) is a later enhancement.
# ---------------------------------------------------------------------------
locals {
  # Globally-unique, deterministic storage account name (<=24 lowercase alphanumerics).
  fslogix_storage_account_name = lower("st${var.workload}${var.environment}${substr(sha1("${var.subscription_id}-${var.workload}-${var.environment}-fslogix"), 0, 8)}")
}

# DEVIATION: native azurerm for the private DNS zone — a trivial resource; avoids the AVM pdns
# module pulling extra azapi/time providers. The §7 vaultcore zone follows the same pattern.
resource "azurerm_private_dns_zone" "file" {
  name                = var.file_private_dns_zone_name
  resource_group_name = azurerm_resource_group.this["workload"].name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  name                  = "link-${local.name_prefix}"
  resource_group_name   = azurerm_resource_group.this["workload"].name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = local.networking.virtual_network_resource_id
  registration_enabled  = false
  tags                  = local.common_tags

  lifecycle {
    precondition {
      condition     = local.networking != null
      error_message = "FSLogix storage (§6) requires deploy_networking = true — it consumes the §4 spoke VNet and private-endpoint subnet."
    }
  }
}

module "fslogix_storage" {
  source = "../../modules/fslogix-storage"

  storage_account_name                = local.fslogix_storage_account_name
  location                            = var.location
  resource_group_resource_id          = azurerm_resource_group.this["workload"].id
  tags                                = local.common_tags
  fslogix_share_quota_gb              = var.fslogix_share_quota_gb
  account_replication_type            = var.fslogix_account_replication_type
  directory_type                      = local.identity.azure_files_directory_service_options
  private_endpoint_subnet_resource_id = local.networking.private_endpoint_subnet_resource_id
  file_private_dns_zone_resource_id   = azurerm_private_dns_zone.file.id
}

# ---------------------------------------------------------------------------
# Security (PROMPT.md §7) — Key Vault + private endpoint + vaultcore DNS zone.
# Gated on deploy_networking (the KV private endpoint consumes the §4 PE subnet).
# ---------------------------------------------------------------------------
locals {
  # No independent enable switch — §7 is bound to deploy_networking because the Key Vault private
  # endpoint consumes the §4 PE subnet. for_each gating is the go-forward pattern (§6 aligns to it
  # via the fix/networking-toggle-correctness branch).
  deploy_security = var.deploy_networking ? toset(["this"]) : toset([])
  key_vault_name  = "kv-${var.workload}-${var.environment}-${substr(sha1("${var.subscription_id}-${var.workload}-${var.environment}-kv"), 0, 6)}"
}

# DEVIATION: native azurerm for the vaultcore private DNS zone — a trivial resource; avoids the AVM
# pdns module pulling extra azapi/time providers (same rationale as the §6 file zone).
resource "azurerm_private_dns_zone" "vault" {
  for_each = local.deploy_security

  name                = var.vault_private_dns_zone_name
  resource_group_name = azurerm_resource_group.this["workload"].name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  for_each = local.deploy_security

  name                  = "link-kv-${local.name_prefix}"
  resource_group_name   = azurerm_resource_group.this["workload"].name
  private_dns_zone_name = azurerm_private_dns_zone.vault["this"].name
  virtual_network_id    = local.networking.virtual_network_resource_id
  registration_enabled  = false
  tags                  = local.common_tags
}

module "security" {
  source   = "../../modules/security"
  for_each = local.deploy_security

  key_vault_name                      = local.key_vault_name
  location                            = var.location
  resource_group_name                 = azurerm_resource_group.this["workload"].name
  tenant_id                           = var.tenant_id
  sku_name                            = var.key_vault_sku
  tags                                = local.common_tags
  private_endpoint_subnet_resource_id = local.networking.private_endpoint_subnet_resource_id
  vault_private_dns_zone_resource_id  = azurerm_private_dns_zone.vault["this"].id
}
