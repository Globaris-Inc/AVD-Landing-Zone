# Purpose: Terraform version constraint for the identity-join config module.
# Section: PROMPT.md §5 — Identity & domain join
# Last updated: 2026-06-10
#
# This module deploys NO Azure resources — it normalises the identity model into configuration
# consumed by the storage (§6) and session-host (§9) sections. No providers are required.

terraform {
  required_version = ">= 1.9, < 2.0"
}
