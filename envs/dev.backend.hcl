# Partial backend config for the dev environment.
# Usage (from a root module, e.g. landing-zones/avd-workload):
#   terraform init -backend-config=../../envs/dev.backend.hcl
# Populate the <…> values from the `bootstrap` outputs after the one-time apply.
# No secrets here — auth is via Entra ID / OIDC (use_azuread_auth = true).

resource_group_name  = "rg-tfstate-avd-001"    # bootstrap output: resource_group_name
storage_account_name = "sttfstatec6dacafe"     # bootstrap output: storage_account_name (deterministic, ADR-0008)
container_name       = "tfstate"               # bootstrap output: storage_container_name
key                  = "avd/dev.terraform.tfstate"
use_azuread_auth     = true
# subscription_id / tenant_id intentionally omitted — supplied via ARM_SUBSCRIPTION_ID / ARM_TENANT_ID
# (local SP env or GitHub Actions repo variables), so no IDs are committed to the repo.
