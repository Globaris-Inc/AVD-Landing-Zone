# Variable values for the prod environment (AVD workload composition root).
# Usage: terraform plan -var-file=../../envs/prod.tfvars
# Subscription/tenant IDs are NOT set here — supplied via TF_VAR_* / CI variables (see note below).

# subscription_id / tenant_id are NOT set here — supplied via TF_VAR_subscription_id / TF_VAR_tenant_id
# (local SP env or GitHub Actions repo variables). -var-file outranks TF_VAR_*, so they must be omitted
# here for the env values to take effect (and to keep IDs out of the repo).
location       = "centralus"
location_short = "cus"
environment    = "prod"
workload       = "avd"

owner               = "avd-poc-team"
cost_center         = "avd-poc"
criticality         = "high"
data_classification = "confidential"

# Optional extra tags merged onto everything:
# tags = { project = "avd-landing-zone" }

# --- Networking (Section 4) ---
deploy_networking              = true
vnet_address_space             = ["10.30.0.0/24"]
session_host_subnet_prefix     = "10.30.0.0/25"
private_endpoint_subnet_prefix = "10.30.0.128/26"
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
# D4as_v4: this subscription has 0 Dasv5 quota; Dasv4 has quota (Total Regional vCPUs = 10, so destroy
# dev before applying prod). Raise quota / change size for a real prod sub.
session_host_count   = 2
session_host_vm_size = "Standard_D4as_v4"
