# Partial backend config for the dev environment.
# Usage (from a root module, e.g. landing-zones/avd-workload):
#   terraform init -backend-config=../../envs/dev.backend.hcl
# Populate the <…> values from the `bootstrap` outputs after the one-time apply.
# No secrets here — auth is via Entra ID / OIDC (use_azuread_auth = true).

resource_group_name  = "<TFSTATE_RG_NAME>"     # bootstrap output: resource_group_name
storage_account_name = "<TFSTATE_SA_NAME>"     # bootstrap output: storage_account_name
container_name       = "tfstate"               # bootstrap output: storage_container_name
key                  = "avd/dev.terraform.tfstate"
use_azuread_auth     = true
subscription_id      = "<AVD_WORKLOAD_SUB_ID>"
tenant_id            = "<TENANT_ID>"
