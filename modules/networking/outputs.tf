# Purpose: Outputs from the networking module (consumed by storage, security, and session-host sections).
# Section: PROMPT.md §4 — Networking (spoke)
# Last updated: 2026-06-10

output "virtual_network_resource_id" {
  description = "Resource ID of the spoke virtual network."
  value       = module.vnet.resource_id
}

output "session_host_subnet_resource_id" {
  description = "Resource ID of the session-host subnet."
  value       = module.vnet.subnets["session_hosts"].resource_id
}

output "private_endpoint_subnet_resource_id" {
  description = "Resource ID of the private-endpoint subnet."
  value       = module.vnet.subnets["private_endpoints"].resource_id
}

output "session_host_asg_resource_id" {
  description = "Resource ID of the session-host application security group."
  value       = module.asg.resource_id
}

output "network_security_group_resource_id" {
  description = "Resource ID of the spoke network security group."
  value       = module.nsg.resource_id
}

output "route_table_resource_id" {
  description = "Resource ID of the spoke route table."
  value       = module.route_table.resource_id
}
