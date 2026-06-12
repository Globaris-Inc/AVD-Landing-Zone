# Purpose: Inputs for the session-hosts module (AVD session-host VMs + AVD agent / Entra join).
# Section: PROMPT.md §9 — Session hosts
# Last updated: 2026-06-11

variable "name_prefix" {
  description = "Naming token, e.g. avd-dev-eus2. Session host VMs are named vm<short>-NN."
  type        = string
}

variable "location" {
  description = "Azure region for the session hosts."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name for the session hosts."
  type        = string
}

variable "tags" {
  description = "Tags applied to the session host resources."
  type        = map(string)
  default     = {}
}

variable "session_host_count" {
  description = "Number of session-host VMs to deploy."
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Session-host VM size."
  type        = string
  default     = "Standard_D4as_v5"
}

variable "admin_username" {
  description = "Local administrator username on the session hosts."
  type        = string
  default     = "avdadmin"
}

variable "subnet_resource_id" {
  description = "Session-host subnet resource ID (NIC placement)."
  type        = string
}

variable "asg_resource_id" {
  description = "Optional application security group resource ID to associate with session-host NICs. Empty skips it."
  type        = string
  default     = ""
}

variable "image_reference" {
  description = "Marketplace image for the session hosts."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "win11-23h2-avd-m365"
    version   = "latest"
  }
}

variable "os_disk_storage_account_type" {
  description = "Storage account type for the session-host OS disk."
  type        = string
  default     = "Premium_LRS"
}

variable "availability_zones" {
  description = "Availability zones to spread session hosts across (cycled by index)."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "host_pool_name" {
  description = "AVD host pool name the session hosts register against."
  type        = string
}

variable "host_pool_registration_token" {
  description = "AVD host pool registration token (sensitive) for the agent DSC extension."
  type        = string
  sensitive   = true
}

variable "entra_id_join" {
  description = "Join session hosts to Microsoft Entra ID (AADLoginForWindows + DSC aadJoin)."
  type        = bool
  default     = true
}
