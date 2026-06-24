# Partial backend config for the prod environment.
# Usage (from a root module, e.g. landing-zones/avd-workload):
#   terraform init -backend-config=../../envs/prod.backend.hcl
# Values below are from the `bootstrap` outputs; subscription/tenant come from env (see note at bottom).
# No secrets here — auth is via Entra ID / OIDC (use_azuread_auth = true).

resource_group_name  = "rg-tfstate-avd-001"    # bootstrap output: resource_group_name
storage_account_name = "sttfstatec6dacafe"     # bootstrap output: storage_account_name (deterministic, ADR-0008)
container_name       = "tfstate"               # bootstrap output: storage_container_name
key                  = "avd/prod.terraform.tfstate" # separate state key from dev (same backend account)
use_azuread_auth     = true
# subscription_id / tenant_id intentionally omitted — supplied via ARM_SUBSCRIPTION_ID / ARM_TENANT_ID
# (local SP env or GitHub Actions repo variables), so no IDs are committed to the repo.
