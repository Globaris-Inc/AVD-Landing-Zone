# Purpose: Log Analytics workspace + AVD data collection rule (perf counters + Windows event logs).
# Section: PROMPT.md §10 — Monitoring (AVD Insights)
# Last updated: 2026-06-11
#
# AVM: operationalinsights-workspace 0.5.1 (resource_group_name), insights-datacollectionrule 0.1.0
# (parent_id). DCR data_sources/destinations/data_flows shapes confirmed at terraform validate.

module "law" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"

  name                                      = "log-${var.name_prefix}"
  location                                  = var.location
  resource_group_name                       = var.resource_group_name
  log_analytics_workspace_sku               = var.law_sku
  log_analytics_workspace_retention_in_days = var.retention_in_days
  tags                                      = var.tags
}

module "dcr" {
  source  = "Azure/avm-res-insights-datacollectionrule/azurerm"
  version = "0.1.0"

  name      = "dcr-${var.name_prefix}"
  location  = var.location
  parent_id = var.resource_group_resource_id
  tags      = var.tags
  kind      = "Windows"

  data_sources = {
    performance_counters = [
      {
        name                          = "perfCounters"
        streams                       = ["Microsoft-Perf"]
        sampling_frequency_in_seconds = 60
        counter_specifiers = [
          "\\LogicalDisk(C:)\\% Free Space",
          "\\Memory\\Available Mbytes",
          "\\Processor Information(_Total)\\% Processor Time",
          "\\Terminal Services(*)\\Active Sessions",
          "\\Terminal Services(*)\\Total Sessions",
        ]
      }
    ]
    windows_event_logs = [
      {
        name    = "eventLogs"
        streams = ["Microsoft-Event"]
        x_path_queries = [
          "System!*[System[(Level=1 or Level=2 or Level=3)]]",
          "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        ]
      }
    ]
  }

  destinations = {
    log_analytics = [
      {
        name                  = "laDestination"
        workspace_resource_id = module.law.resource_id
      }
    ]
  }

  data_flows = [
    {
      streams      = ["Microsoft-Perf", "Microsoft-Event"]
      destinations = ["laDestination"]
    }
  ]
}
