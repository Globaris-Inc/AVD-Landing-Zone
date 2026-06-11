# Purpose: OIDC federated identity for GitHub Actions — Entra app, SP, federated creds, RBAC.
# Section: PROMPT.md §2 — Bootstrap (OIDC, state backend, providers)
# Last updated: 2026-06-10
#
# No client secret is created — all auth is via OIDC federated credentials (DECISIONS.md ADR-0002).
#
# RBAC scope: Owner on the AVD subscription(s) — NOT the Tenant Root MG (platform/management groups
# are out of scope). Owner is used because the application landing zone creates role assignments
# (e.g. AVD/storage RBAC); scope-down to Contributor + User Access Administrator is tracked in
# OPEN-QUESTIONS.md (OQ-007).

data "azuread_client_config" "current" {}

locals {
  # Grant the CI principal access to the workload subscription and, if set, shared-services.
  target_subscription_ids = toset(compact([
    var.subscription_id,
    var.shared_services_subscription_id,
  ]))
}

# ---------------------------------------------------------------------------
# Entra ID application + service principal (workload identity only)
# ---------------------------------------------------------------------------

resource "azuread_application" "oidc" {
  display_name = "sp-${var.workload}-lz-cicd"
  # No redirect URIs / implicit grants / API permissions — access is via ARM RBAC only.
}

resource "azuread_service_principal" "oidc" {
  client_id                    = azuread_application.oidc.client_id
  app_role_assignment_required = false
}

# ---------------------------------------------------------------------------
# Federated identity credentials (OIDC — no client_secret)
# ---------------------------------------------------------------------------

# push to main -> apply workflow
resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.oidc.id
  display_name   = "github-main-branch"
  description    = "GitHub Actions OIDC — push to main (apply-on-merge)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

# pull_request events -> plan workflow
resource "azuread_application_federated_identity_credential" "pull_request" {
  application_id = azuread_application.oidc.id
  display_name   = "github-pull-request"
  description    = "GitHub Actions OIDC — pull_request events (plan-on-pr)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

# GitHub Environment-gated apply (Settings -> Environments -> "production").
resource "azuread_application_federated_identity_credential" "prod_environment" {
  application_id = azuread_application.oidc.id
  display_name   = "github-env-production"
  description    = "GitHub Actions OIDC — production environment (gated apply)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:production"
}

# ---------------------------------------------------------------------------
# RBAC — Owner on the AVD subscription(s) (OQ-007 tracks scope-down)
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "oidc_owner_subscription" {
  for_each = local.target_subscription_ids

  scope                            = "/subscriptions/${each.value}"
  role_definition_name             = "Owner"
  principal_id                     = azuread_service_principal.oidc.object_id
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------
# RBAC — Storage data plane on the state account (control-plane Owner does not
# grant blob data access when shared keys are disabled).
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "oidc_storage_blob_contributor" {
  scope                            = azurerm_storage_account.tfstate.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.oidc.object_id
  skip_service_principal_aad_check = true
}

# Deployer needs the same data-plane role to run local terraform against the remote state.
resource "azurerm_role_assignment" "deployer_storage_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
