# Purpose: Spoke networking — NSG, ASG, route table, and VNet (with subnets + optional peering).
# Section: PROMPT.md §4 — Networking (spoke)
# Last updated: 2026-06-10
#
# Composed from pinned AVM resource modules (I/O confirmed against each module's docs):
#   avm-res-network-networksecuritygroup 0.5.1, -applicationsecuritygroup 0.1.1,
#   -routetable 0.5.0, -virtualnetwork 0.17.1 (uses parent_id; subnets/peerings are maps).
# Final validation (terraform init/validate) runs in CI — see WORKLOG.

locals {
  # Optional hub peering — created only when a hub VNet resource ID is supplied.
  peerings = var.hub_vnet_resource_id == "" ? {} : {
    to_hub = {
      name                               = "peer-to-hub"
      remote_virtual_network_resource_id = var.hub_vnet_resource_id
      allow_forwarded_traffic            = true
      allow_virtual_network_access       = true
      use_remote_gateways                = false # set true once the hub gateway exists
    }
  }

  # Optional default egress route to the platform firewall.
  routes = var.firewall_private_ip == "" ? {} : {
    default_to_firewall = {
      name                   = "default-to-firewall"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.firewall_private_ip
    }
  }
}

# ---------------------------------------------------------------------------
# Network Security Group — AVD reverse-connect (no inbound RDP from the internet)
# ---------------------------------------------------------------------------
module "nsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  name                = "nsg-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # These two rules explicitly restate Azure's platform default NSG rules (AllowVnetInBound /
  # DenyAllInBound) to make the reverse-connect intent visible and auditable. Outbound is left to the
  # platform defaults so the AVD agents can reach the control plane over 443.
  security_rules = {
    allow_vnet_inbound = {
      name                       = "Allow-VnetInbound"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_address_prefix      = "VirtualNetwork"
      source_port_range          = "*"
      destination_address_prefix = "VirtualNetwork"
      destination_port_range     = "*"
    }
    deny_all_inbound = {
      name                       = "Deny-AllInbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "*"
    }
  }
}

# ---------------------------------------------------------------------------
# Application Security Group — for session-host NICs
# ---------------------------------------------------------------------------
module "asg" {
  source  = "Azure/avm-res-network-applicationsecuritygroup/azurerm"
  version = "0.1.1"

  name                = "asg-sh-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Route Table — default egress to the platform firewall (optional)
# ---------------------------------------------------------------------------
module "route_table" {
  source  = "Azure/avm-res-network-routetable/azurerm"
  version = "0.5.0"

  name                = "rt-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  routes = local.routes
}

# ---------------------------------------------------------------------------
# Virtual Network — spoke with session-host + private-endpoint subnets
# ---------------------------------------------------------------------------
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  name          = "vnet-${var.name_prefix}"
  location      = var.location
  parent_id     = var.resource_group_resource_id
  address_space = var.address_space
  tags          = var.tags

  subnets = {
    session_hosts = {
      name             = "snet-sessionhosts"
      address_prefixes = [var.session_host_subnet_prefix]
      network_security_group = {
        id = module.nsg.resource_id
      }
      route_table = {
        id = module.route_table.resource_id
      }
    }
    private_endpoints = {
      name             = "snet-privateendpoints"
      address_prefixes = [var.private_endpoint_subnet_prefix]
      network_security_group = {
        id = module.nsg.resource_id
      }
      # Private endpoints need PE network policies relaxed on their subnet. "Disabled" turns off both
      # NSG and UDR enforcement for PEs; switch to "NetworkSecurityGroupEnabled" to keep NSG rules
      # applied to private-endpoint NICs.
      private_endpoint_network_policies = "Disabled"
    }
  }

  peerings = local.peerings
}
