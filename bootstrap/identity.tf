# Purpose: OIDC federated identity for GitHub Actions — Entra app, SP, federated creds, RBAC.
# Section: PROMPT.md §2 — Bootstrap (OIDC, state backend, providers)
# Last updated: 2026-06-10
#
# No client secret is created — all auth is via OIDC federated credentials (DECISIONS.md ADR-0002).
#
# RBAC scope: Contributor + User Access Administrator on the AVD subscription(s) — NOT the Tenant Root
# MG (platform/management groups are out of scope). Contributor manages resources; User Access
# Administrator lets the application landing zone create role assignments (AVD/storage RBAC). Together
# they replace Owner (least-privilege — DECISIONS.md ADR-0005, resolves OQ-007).
#
# Toggle: when var.create_oidc_identity = false, the OIDC app/SP/federated-credentials and the
# subscription RBAC below are skipped (reuse an existing app registration instead — wire its RBAC and
# federated credentials separately). The deployer's state-account data-plane role is always created.

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
  count        = var.create_oidc_identity ? 1 : 0
  display_name = "sp-${var.workload}-lz-cicd"
  # No redirect URIs / implicit grants / API permissions — access is via ARM RBAC only.
}

resource "azuread_service_principal" "oidc" {
  count                        = var.create_oidc_identity ? 1 : 0
  client_id                    = azuread_application.oidc[0].client_id
  app_role_assignment_required = false
}

# ---------------------------------------------------------------------------
# Federated identity credentials (OIDC — no client_secret)
# ---------------------------------------------------------------------------

# push to main -> apply workflow
resource "azuread_application_federated_identity_credential" "main_branch" {
  count          = var.create_oidc_identity ? 1 : 0
  application_id = azuread_application.oidc[0].id
  display_name   = "github-main-branch"
  description    = "GitHub Actions OIDC — push to main (apply-on-merge)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

# pull_request events -> plan workflow
resource "azuread_application_federated_identity_credential" "pull_request" {
  count          = var.create_oidc_identity ? 1 : 0
  application_id = azuread_application.oidc[0].id
  display_name   = "github-pull-request"
  description    = "GitHub Actions OIDC — pull_request events (plan-on-pr)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

# GitHub Environment-gated apply (Settings -> Environments -> "production").
resource "azuread_application_federated_identity_credential" "prod_environment" {
  count          = var.create_oidc_identity ? 1 : 0
  application_id = azuread_application.oidc[0].id
  display_name   = "github-env-production"
  description    = "GitHub Actions OIDC — production environment (gated apply)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:production"
}

# ---------------------------------------------------------------------------
# RBAC — Contributor + User Access Administrator on the AVD subscription(s)
# (least-privilege replacement for Owner — ADR-0005, resolves OQ-007).
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "oidc_contributor_subscription" {
  for_each = var.create_oidc_identity ? local.target_subscription_ids : toset([])

  scope                            = "/subscriptions/${each.value}"
  role_definition_name             = "Contributor"
  principal_id                     = azuread_service_principal.oidc[0].object_id
  skip_service_principal_aad_check = true
}

# User Access Administrator — the application landing zone creates role assignments (AVD/storage RBAC),
# which Contributor cannot.
resource "azurerm_role_assignment" "oidc_user_access_admin_subscription" {
  for_each = var.create_oidc_identity ? local.target_subscription_ids : toset([])

  scope                            = "/subscriptions/${each.value}"
  role_definition_name             = "User Access Administrator"
  principal_id                     = azuread_service_principal.oidc[0].object_id
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------
# RBAC — Storage data plane on the state account for the CI principal (only when creating a NEW OIDC
# identity; control-plane Contributor does not grant blob data access when shared keys are disabled).
# When reusing an existing app reg (create_oidc_identity = false), the deployer role in main.tf already
# covers it because the deployer IS that same service principal.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "oidc_storage_blob_contributor" {
  count                            = var.create_oidc_identity ? 1 : 0
  scope                            = azurerm_storage_account.tfstate.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.oidc[0].object_id
  skip_service_principal_aad_check = true
}
