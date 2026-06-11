# Purpose: Naming convention and common tags for all AVD workload resources.
# Section: PROMPT.md §3 — Resource organization, naming & tagging
# Last updated: 2026-06-10
#
# Names follow docs/naming-and-tagging.md: <abbreviation>-<workload>-<environment>-<region-short>.
# Centralising naming + tags here keeps every module consistent and environment-driven.

locals {
  # Common token used across resource names, e.g. "avd-dev-eus2".
  name_prefix = "${var.workload}-${var.environment}-${var.location_short}"

  # Resource group names (per the reference architecture: one workload RG, one shared-services RG).
  resource_group_names = {
    workload = "rg-${local.name_prefix}"
    shared   = "rg-${var.workload}-shared-${var.environment}-${var.location_short}"
  }

  # Naming context passed to downstream modules so they derive names consistently.
  naming = {
    prefix         = local.name_prefix
    workload       = var.workload
    environment    = var.environment
    location_short = var.location_short
  }

  # Minimum tags from docs/naming-and-tagging.md, merged with caller-supplied var.tags.
  common_tags = merge(
    {
      workload           = var.workload
      environment        = var.environment
      owner              = var.owner
      costCenter         = var.cost_center
      criticality        = var.criticality
      managedBy          = "iac-terraform"
      dataClassification = var.data_classification
    },
    var.tags
  )
}
