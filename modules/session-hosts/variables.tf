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
  description = "Application security group resource ID to associate with session-host NICs (used when enable_asg_association = true)."
  type        = string
  default     = ""
}

variable "enable_asg_association" {
  description = "Associate session-host NICs with var.asg_resource_id. Gated on a static bool (not the asg id) so plan works on a greenfield apply where the id isn't known yet."
  type        = bool
  default     = false
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

variable "intune_enrollment" {
  description = "Auto-enroll session hosts into Microsoft Intune during Entra join (adds mdmId to the AADLoginForWindows extension). Requires entra_id_join = true plus tenant-side MDM auto-enrollment scope and Intune licensing; has no effect when entra_id_join = false."
  type        = bool
  default     = false
}

variable "encryption_at_host_enabled" {
  description = "Enable encryption at host. Requires the Microsoft.Compute/EncryptionAtHost feature registered on the subscription; set false if it isn't registered yet."
  type        = bool
  default     = true
}

variable "avd_agent_dsc_modules_url" {
  description = "URL of the AVD agent DSC configuration package. Pinned to a versioned package whose AddSessionHost accepts the aadJoin parameter — the unversioned 'always-latest' Configuration.zip dropped aadJoin and fails on Entra-join host pools (RDS-Templates issue #598). The AVD agent self-updates after registration, so the bootstrap package version mainly affects the registration step."
  type        = string
  default     = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02627.270.zip"
}
