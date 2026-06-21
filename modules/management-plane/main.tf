# Purpose: AVD management plane — host pool, application group, workspace, scaling plan.
# Section: PROMPT.md §8 — Management plane
# Last updated: 2026-06-11
#
# AVM: desktopvirtualization-{hostpool 0.4.0, applicationgroup 0.2.1, workspace 0.2.2, scalingplan 0.2.1}.

# NOTE: diagnostic_settings are intentionally NOT wired here — the Log Analytics workspace is created
# in §10 (Monitoring). Diagnostics for these resources are wired in §10. (Tracked in WORKLOG/OPEN-QUESTIONS.)

locals {
  load_balancer_type       = var.host_pool_type == "Personal" ? "Persistent" : "BreadthFirst"
  preferred_app_group_type = var.app_group_type == "RemoteApp" ? "RailApplications" : "Desktop"

  # Diagnostic settings → Log Analytics (§10, always deployed in this composition). The key is static so
  # for_each keys are known at plan even on a greenfield apply where the workspace id isn't known yet
  # (Terraform allows unknown values in for_each, but not unknown keys).
  diagnostic_settings = {
    to_law = {
      name                  = "diag-to-law"
      workspace_resource_id = var.log_analytics_workspace_resource_id
    }
  }
}

module "host_pool" {
  source  = "Azure/avm-res-desktopvirtualization-hostpool/azurerm"
  version = "0.4.0"

  resource_group_name                                = var.resource_group_name
  virtual_desktop_host_pool_name                     = "vdpool-${var.name_prefix}"
  virtual_desktop_host_pool_location                 = var.location
  virtual_desktop_host_pool_resource_group_name      = var.resource_group_name
  virtual_desktop_host_pool_type                     = var.host_pool_type
  virtual_desktop_host_pool_load_balancer_type       = local.load_balancer_type
  virtual_desktop_host_pool_preferred_app_group_type = local.preferred_app_group_type
  virtual_desktop_host_pool_maximum_sessions_allowed = var.max_sessions_allowed
  virtual_desktop_host_pool_start_vm_on_connect      = var.start_vm_on_connect
  virtual_desktop_host_pool_tags                     = var.tags

  diagnostic_settings = local.diagnostic_settings
}

module "application_group" {
  source  = "Azure/avm-res-desktopvirtualization-applicationgroup/azurerm"
  version = "0.2.1"

  virtual_desktop_application_group_name                = "vdag-${var.name_prefix}"
  virtual_desktop_application_group_location            = var.location
  virtual_desktop_application_group_resource_group_name = var.resource_group_name
  virtual_desktop_application_group_host_pool_id        = module.host_pool.resource_id
  virtual_desktop_application_group_type                = var.app_group_type
  virtual_desktop_application_group_tags                = var.tags
}

module "workspace" {
  source  = "Azure/avm-res-desktopvirtualization-workspace/azurerm"
  version = "0.2.2"

  virtual_desktop_workspace_name                = "vdws-${var.name_prefix}"
  virtual_desktop_workspace_location            = var.location
  virtual_desktop_workspace_resource_group_name = var.resource_group_name
  virtual_desktop_workspace_tags                = var.tags

  diagnostic_settings = local.diagnostic_settings
}

# DEVIATION: native azurerm — the AVM workspace module exposes no application-group association input.
# NOTE: avm-res-desktopvirtualization-workspace 0.2.2's `resource_id` output returns the whole resource
# object (not the id string, unlike the host_pool module) — hence `.resource_id.id`.
resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  workspace_id         = module.workspace.resource_id.id
  application_group_id = module.application_group.resource_id
}

# Pooled autoscale schedule. Personal host pools need a different (personal) schedule shape.
module "scaling_plan" {
  source  = "Azure/avm-res-desktopvirtualization-scalingplan/azurerm"
  version = "0.2.1"

  for_each = var.deploy_scaling_plan && var.host_pool_type == "Pooled" ? toset(["this"]) : toset([])

  virtual_desktop_scaling_plan_name                = "vdscaling-${var.name_prefix}"
  virtual_desktop_scaling_plan_location            = var.location
  virtual_desktop_scaling_plan_resource_group_name = var.resource_group_name
  virtual_desktop_scaling_plan_time_zone           = var.time_zone

  virtual_desktop_scaling_plan_host_pool = [
    {
      hostpool_id          = module.host_pool.resource_id
      scaling_plan_enabled = true
    }
  ]

  virtual_desktop_scaling_plan_schedule = [
    {
      name                                 = "weekdays"
      days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      ramp_up_start_time                   = "07:00"
      ramp_up_load_balancing_algorithm     = "BreadthFirst"
      ramp_up_capacity_threshold_percent   = 60
      ramp_up_minimum_hosts_percent        = 20
      peak_start_time                      = "09:00"
      peak_load_balancing_algorithm        = "BreadthFirst"
      ramp_down_start_time                 = "18:00"
      ramp_down_load_balancing_algorithm   = "DepthFirst"
      ramp_down_capacity_threshold_percent = 90
      ramp_down_minimum_hosts_percent      = 10
      ramp_down_wait_time_minutes          = 30
      ramp_down_notification_message       = "You will be logged off soon. Please save your work."
      ramp_down_force_logoff_users         = false
      ramp_down_stop_hosts_when            = "ZeroSessions"
      off_peak_start_time                  = "20:00"
      off_peak_load_balancing_algorithm    = "DepthFirst"
    }
  ]
  virtual_desktop_scaling_plan_tags = var.tags
}
