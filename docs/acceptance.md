# Acceptance & Validation

What has been verified, what to check before the first apply, and the acceptance criteria for the AVD
landing zone (PROMPT.md §13).

## Verified in this repo

- **`terraform validate` clean** on both roots: `bootstrap/` and `landing-zones/avd-workload/`
  (Terraform v1.15.6, providers + all AVM modules resolved; CI pins 1.9.8 — both satisfy `>= 1.9`). One warning originates *inside* the pinned
  Log Analytics AVM module (`local_authentication_disabled`) and is not actionable here.
- **`terraform fmt -recursive`** clean.
- Every section passed the **`code-reviewer` gate**. §10/§11 were self-reviewed at section time (the
  reviewer subagent hit a session limit), then **re-reviewed in a follow-up gap-closing pass** that
  caught and fixed a storage-diagnostics bug (empty log/metric categories).
- **No secrets / real subscription/tenant IDs** committed — all `<PLACEHOLDER>`s.

> Not verified here: a real `terraform plan`/`apply` against a subscription (no cloud credentials in the
> build environment). Value-level correctness (SKUs, the AVD-agent DSC artifact, region feature support)
> is confirmed by a `plan` once credentials exist.

## Pre-apply checklist

1. Run `bootstrap/` once; capture outputs into `envs/<env>.backend.hcl` + GitHub repo variables
   (`AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`). Create the **`production`** GitHub
   Environment with a required reviewer.
2. Replace every `<PLACEHOLDER>` in `envs/*.tfvars` (subscription/tenant IDs, owner, cost center).
3. **OQ-008 (resolved):** either register `Microsoft.Compute/EncryptionAtHost` on the subscription
   (`az feature register --namespace Microsoft.Compute --name EncryptionAtHost`) **or** set
   `session_host_encryption_at_host = false` in `envs/*.tfvars` if it isn't registered. Default is `true`.
4. **OQ-008 (resolved):** the AVD-agent DSC `modulesUrl` defaults to the always-latest
   `galleryartifacts/Configuration.zip`; pin a versioned `Configuration_x.y.z.zip` via
   `var.avd_agent_dsc_modules_url` in `modules/session-hosts` if you need reproducible builds.
5. **OQ-007 (resolved):** the CI service principal is scoped to **Contributor + User Access Administrator**
   (ADR-0005) — no further action needed before enabling the apply workflow.
6. Run `terraform plan` (CI `plan-on-pr`) and review before merging.

## Acceptance criteria (post-deploy)

- [ ] `terraform apply` succeeds end-to-end from a clean subscription.
- [ ] All PaaS (storage, Key Vault) resolves via **private endpoint** (verify with `nslookup` from a
      session host — should return the `privatelink.*` IP).
- [ ] A user can launch a desktop from the **AVD client**, and the session host is Entra-joined.
- [ ] The **FSLogix profile** loads from the Azure Files share at logon.
- [ ] **AVD Insights** shows the host pool, sessions, and performance data (DCR + AMA flowing to LAW).
- [ ] The **autoscale scaling plan** ramps session hosts on its schedule.
- [ ] `terraform destroy` cleanly removes everything.
