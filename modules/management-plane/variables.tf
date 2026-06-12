# Purpose: Inputs for the AVD management-plane module (workspace, host pool, app group, scaling plan).
# Section: PROMPT.md §8 — Management plane
# Last updated: 2026-06-11

variable "name_prefix" {
  description = "Naming token, e.g. avd-dev-eus2. Used to build resource names."
  type        = string
}

variable "location" {
  description = "Azure region for the management-plane resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name for the management-plane resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to all management-plane resources."
  type        = map(string)
  default     = {}
}

variable "host_pool_type" {
  description = "Host pool type: Pooled or Personal."
  type        = string
  default     = "Pooled"

  validation {
    condition     = contains(["Pooled", "Personal"], var.host_pool_type)
    error_message = "host_pool_type must be Pooled or Personal."
  }
}

variable "max_sessions_allowed" {
  description = "Maximum sessions per host (Pooled host pools)."
  type        = number
  default     = 8
}

variable "start_vm_on_connect" {
  description = "Power on a stopped session host when a user connects."
  type        = bool
  default     = true
}

variable "app_group_type" {
  description = "Application group type: Desktop or RemoteApp."
  type        = string
  default     = "Desktop"

  validation {
    condition     = contains(["Desktop", "RemoteApp"], var.app_group_type)
    error_message = "app_group_type must be Desktop or RemoteApp."
  }
}

variable "time_zone" {
  description = "Time zone for the scaling plan schedule (e.g. UTC)."
  type        = string
  default     = "UTC"
}

variable "deploy_scaling_plan" {
  description = "Deploy an autoscale scaling plan (Pooled host pools only)."
  type        = bool
  default     = true
}
