# Purpose: Inputs for the networking module (spoke VNet, NSG, ASG, route table, peering).
# Section: PROMPT.md §4 — Networking (spoke)
# Last updated: 2026-06-10

variable "name_prefix" {
  description = "Naming token, e.g. avd-dev-eus2. Used to build resource names (nsg-<prefix>, vnet-<prefix>, ...)."
  type        = string
}

variable "location" {
  description = "Azure region for the networking resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group NAME — used by the NSG, ASG, and route-table modules."
  type        = string
}

variable "resource_group_resource_id" {
  description = "Resource group RESOURCE ID — used as the virtual-network module's parent_id (/subscriptions/.../resourceGroups/...)."
  type        = string
}

variable "tags" {
  description = "Tags applied to all networking resources."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Addressing
# ---------------------------------------------------------------------------

variable "address_space" {
  description = "Spoke VNet address space (CIDR list)."
  type        = list(string)
}

variable "session_host_subnet_prefix" {
  description = "CIDR for the session-host subnet."
  type        = string
}

variable "private_endpoint_subnet_prefix" {
  description = "CIDR for the private-endpoint subnet."
  type        = string
}

# ---------------------------------------------------------------------------
# Connectivity (optional)
# ---------------------------------------------------------------------------

variable "hub_vnet_resource_id" {
  description = "Resource ID of the platform hub VNet to peer with. Empty disables peering."
  type        = string
  default     = ""
}

variable "firewall_private_ip" {
  description = "Platform firewall private IP for the default egress route (0.0.0.0/0). Empty omits the default route."
  type        = string
  default     = ""
}
