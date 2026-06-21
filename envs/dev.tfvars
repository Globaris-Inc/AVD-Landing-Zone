# Variable values for the dev environment (AVD workload composition root).
# Usage: terraform plan -var-file=../../envs/dev.tfvars
# Replace every <…> placeholder. No secrets here — subscription ID is not secret, but per project
# rules use a placeholder in the repo and supply the real value via your local copy / CI variables.

# subscription_id and tenant_id are intentionally NOT set here — they are supplied via TF_VAR_subscription_id
# / TF_VAR_tenant_id (local SP env or GitHub Actions repo variables). Note -var-file outranks TF_VAR_*, so
# leaving them out of this file is required for the env values to take effect (and keeps IDs out of the repo).
location       = "centralus"
location_short = "cus"
environment    = "dev"
workload       = "avd"

owner               = "avd-poc-team"
cost_center         = "avd-poc"
criticality         = "medium"
data_classification = "confidential"

# Optional extra tags merged onto everything:
# tags = { project = "avd-landing-zone" }

# --- Networking (Section 4) ---
deploy_networking              = true
vnet_address_space             = ["10.20.0.0/24"]
session_host_subnet_prefix     = "10.20.0.0/25"
private_endpoint_subnet_prefix = "10.20.0.128/26"
hub_vnet_resource_id           = "" # set to the platform hub VNet resource ID to enable peering
firewall_private_ip            = "" # set to the platform firewall private IP to add the default route

# --- Identity (Section 5, ADR-0003) ---
identity_mode = "entra-id-join"
# domain_fqdn    = "corp.contoso.com"   # only for entra-ds / ad-ds
# domain_ou_path = "OU=AVD,DC=corp,DC=contoso,DC=com"

# --- FSLogix storage (Section 6) ---
fslogix_share_quota_gb           = 128
fslogix_account_replication_type = "ZRS"

# --- Security (Section 7) ---
# tenant_id supplied via TF_VAR_tenant_id (see note at top).
key_vault_sku = "standard"

# --- Management plane (Section 8) ---
host_pool_type       = "Pooled"
max_sessions_allowed = 8

# --- Session hosts (Section 9) ---
# NOTE: Standard_D4as_v5 hit a 0-quota wall on this PoC sub; Dasv4 has quota (Total Regional vCPUs = 10).
# D4as_v4 = 4 cores, supports encryption-at-host. 2 hosts = 8 cores, within the regional cap.
session_host_count   = 2
session_host_vm_size = "Standard_D4as_v4"
