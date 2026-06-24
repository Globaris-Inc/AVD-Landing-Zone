# DECISIONS.md — Architecture Decision Records

> Append-only. Newest at the bottom. One ADR per significant decision: context → decision →
> consequences → alternatives. Supersede (don't delete) with a new ADR that references the old one.

---

## ADR-0001 — Stack, module strategy, layout, CI/CD, and ways of working

- **Status:** Accepted
- **Date:** 2026-06-10
- **Deciders:** Project owner + Cloud Solutions Architect

### Context
Bootstrapping an AVD **application** landing zone as IaC, to follow the same governance and structure as
the sibling repo `Azure-Architecture` (a Terraform + AVM Azure Landing Zone PoC).

### Decision
1. **Terraform + AVM only.** The earlier "both Bicep and Terraform" direction is **reversed** — Bicep is
   **dropped** to match the reference pattern and avoid maintaining two parallel stacks. The partial
   Bicep work under `infra/bicep/` is removed in Section 1 (Repository Structure).
2. **Compose from published AVM resource modules** (`Azure/avm-res-*`); use `Azure/avm-ptn-*` only where a
   published pattern fits. The AVD pattern modules (`avm/ptn/avd-lza/*`) are proposed/unversioned — not used.
3. **Re-pattern the repo** to the reference layout: root governance docs + `bootstrap/ envs/ modules/
   landing-zones/ policies/` + `.github/workflows/{plan-on-pr,apply-on-merge}.yml`.
4. **CI/CD = GitHub Actions + OIDC** federated auth; no stored cloud secrets.
5. **Keep the four role subagents** (Architect / Cloud Engineer / DevSecOps / Code Reviewer); they operate
   within the section-per-session model defined in `CLAUDE.md`.
6. **Governance = the Azure-Architecture contract:** user-authored `CLAUDE.md` + `PROMPT.md`, `WORKLOG.md`
   as source of truth, `DECISIONS.md` + `OPEN-QUESTIONS.md`, one section per session, verify-before-write,
   pin all versions, stop-and-ask on ambiguity.

### Consequences
- **Pro:** single maintained stack; consistent with the reference repo; tested AVM building blocks;
  no secrets in CI; clear ownership and cross-session continuity.
- **Con:** the Bicep work done on 2026-06-10 is discarded; AVM version bumps need periodic maintenance.

### Alternatives considered
- **Keep both Bicep + Terraform** — rejected: doubles maintenance; the reference has no Bicep.
- **Bicep only** — rejected: diverges from the Terraform-based reference pattern.
- **Wrap `Azure/avdaccelerator` directly** — rejected earlier: we want an owned, reviewable codebase.

> Supersedes the bootstrap-era ADR formerly at `docs/decisions/0001-iac-and-modules.md` (retired in
> Section 1; its pinned AVM version matrix lives in git history if needed).

---

## ADR-0002 — Bootstrap layer (state backend + OIDC identity)

- **Status:** Accepted
- **Date:** 2026-06-10
- **Deciders:** DevSecOps Engineer + Cloud Solutions Architect

### Context
PROMPT.md §2 requires a one-time bootstrap that creates the Terraform remote-state backend and the
GitHub Actions OIDC identity before any other root module can run. Modeled on the validated sibling
repo `Azure-Architecture`, adapted for an **application** landing zone.

### Decision
1. **Bootstrap uses local state**; it creates the backend the other roots consume, so it cannot depend
   on it. `bootstrap/terraform.tfvars` and its local state are gitignored.
2. **Remote state = Azure Storage**: GZRS, **customer-managed key** (Key Vault + user-assigned identity),
   blob versioning, **shared access keys disabled** (Entra-ID/RBAC only), unlocked container immutability.
3. **CI auth = OIDC federated credentials** — no client secrets. Federated subjects for `main` push,
   `pull_request`, and the `production` GitHub Environment. Client/tenant/subscription IDs are surfaced
   as GitHub **repository variables**, not secrets.
4. **RBAC scope = Owner on the AVD subscription(s)** (workload + optional shared-services), **not** the
   Tenant Root management group — management groups are platform scope, out of scope here. Owner is used
   because the application landing zone creates role assignments; scope-down is tracked in OQ-007.
   _(Superseded by ADR-0005: scoped down to Contributor + User Access Administrator.)_
5. **Temporary public access** on the state Storage Account via an IP allow-list, removed when §7 adds a
   Private Endpoint (documented `# DEVIATION`).

### Consequences
- **Pro:** secret-less CI; encrypted, versioned, recoverable state; subscription-scoped RBAC; consistent
  with the reference repo and reproducible.
- **Con:** bootstrap local state must be protected/recreated by import if lost; CMK adds RBAC-timing
  complexity (handled with a `time_sleep`); Owner is broader than ideal until OQ-007 is actioned.

### Alternatives considered
- **Service principal with a client secret** — rejected: secrets in CI.
- **Owner at Tenant Root MG** (as in the reference) — rejected: platform/MG scope, out of scope here.
- **No CMK / platform-managed keys** — viable, but CMK matches the enterprise-grade reference posture.

---

## ADR-0003 — Session-host identity model: Microsoft Entra ID join

- **Status:** Accepted
- **Date:** 2026-06-10
- **Deciders:** Project owner + Cloud Solutions Architect (resolves OQ-006)

### Context
The session hosts need an identity/join model; it drives the session-host join configuration and the
FSLogix Azure Files authentication mode. PROMPT.md §5 exposes a `identity_mode` toggle.

### Decision
**Microsoft Entra ID join** (cloud-only) is the baseline.
- Session hosts join Entra ID via the **`AADLoginForWindows`** VM extension (wired in §9).
- FSLogix on Azure Files authenticates with **Entra Kerberos** — `directory_service_options = "AADKERB"`
  (wired in §6).
- **No domain controllers / Entra DS are deployed here** — the identity platform is a prerequisite
  (out of scope). For `entra-ds`/`ad-ds` the module only produces *domain-join configuration* (FQDN/OU
  + Key Vault credential references) pointing at the platform-provided domain.
- The `identity_mode` toggle (`entra-id-join` | `entra-ds` | `ad-ds`) is retained for portability; only
  `entra-id-join` is realised now.

### Consequences
- **Pro:** simplest and cloud-native; no DC infrastructure; integrates with Conditional Access + SSO;
  Entra Kerberos removes the need for AD DS to use Azure Files.
- **Con:** legacy/Kerberos-dependent apps may still require AD DS (revisit per workload); Entra Kerberos
  has prerequisites (storage Entra Kerberos config, client OS support); SSO/CA must be configured.

### Alternatives considered
- **Microsoft Entra Domain Services** — managed domain; more cost/ops, useful for legacy auth.
- **Self-managed AD DS** — full control, most operational overhead; DCs are platform scope.

---

## ADR-0004 — Native `azurerm` private DNS zones (not the AVM pdns module)

- **Status:** Accepted
- **Date:** 2026-06-12
- **Deciders:** Cloud Solutions Architect + Cloud Engineer

### Context
§6 (FSLogix storage) and §7 (Key Vault) need `privatelink.file.*` / `privatelink.vaultcore.azure.net`
private DNS zones (+ VNet links) for their private endpoints.

### Decision
Create these with **native `azurerm_private_dns_zone` + `azurerm_private_dns_zone_virtual_network_link`**
in the composition root, rather than `Azure/avm-res-network-privatednszone`. Documented with `# DEVIATION`.

### Consequences
- **Pro:** trivial, unambiguous resources; avoids pulling the AVM pdns module's extra `azapi`/`time`
  providers and its less-obvious `virtual_network_links` schema. Consistent pattern for both zones.
- **Con:** a deliberate deviation from "compose from AVM"; if the platform team later provides shared
  `privatelink.*` zones (connectivity subscription), switch to consuming those instead of creating them.

### Alternatives considered
- **`avm-res-network-privatednszone`** — extra provider deps + schema ambiguity for a one-resource need.
- **Consume platform-provided zones** — preferred in a mature platform LZ; not assumed available here.

---

## ADR-0005 — Scope the CI principal to Contributor + User Access Administrator (not Owner)

- **Status:** Accepted
- **Date:** 2026-06-14
- **Deciders:** DevSecOps Engineer + Project owner (resolves OQ-007)

### Context
ADR-0002 (point 4) granted the OIDC CI service principal **Owner** on the AVD subscription(s) because the
application landing zone creates **role assignments** (AVD RBAC, storage data-plane RBAC), which the
**Contributor** role cannot. Owner is broader than the pipeline needs and was flagged for scope-down in
OQ-007.

### Decision
Replace the single **Owner** assignment with two least-privilege assignments at subscription scope:
1. **Contributor** — create/manage all AVD landing-zone resources.
2. **User Access Administrator** — create the role assignments the landing zone needs (e.g. session-host
   Entra login, Storage Blob/File data-plane roles) that Contributor is denied.

Implemented in `bootstrap/identity.tf` as `azurerm_role_assignment.oidc_contributor_subscription` and
`oidc_user_access_admin_subscription` (both `for_each` over the target subscriptions). The state-account
`Storage Blob Data Contributor` assignment is unchanged.

### Consequences
- **Pro:** least privilege — the CI principal can no longer manage Blueprints/locks or other Owner-only
  surfaces it never uses, while retaining the ability to assign roles. Closes OQ-007.
- **Con:** if a future resource needs an Owner-only action, an additional narrowly-scoped role assignment
  must be added rather than relying on blanket Owner.

### Alternatives considered
- **Keep Owner** — rejected: broader than required; fails least-privilege review.
- **Contributor only** — rejected: cannot create role assignments, so AVD/storage RBAC apply would fail.
- **Custom role** with an explicit action allow-list — more precise, but higher maintenance; the two
  built-in roles are the standard, well-understood pairing for this need.

> Supersedes ADR-0002 point 4 (Owner on the AVD subscription).

---

## ADR-0006 — Microsoft Intune integration: auto-enroll hook only (config plane out of scope)

- **Status:** Accepted
- **Date:** 2026-06-14
- **Deciders:** Cloud Solutions Architect + Project owner

### Context
A requirement to manage AVD session hosts with **Microsoft Intune** (MDM). Intune management of session
hosts is enabled by **Entra ID join**, which is already the baseline (ADR-0003). The question is how much
of the Intune integration belongs in this **application** landing zone vs. the control plane.

Intune itself has **no `azurerm`/AVM resource surface** — it is configured through Microsoft Graph
(configuration profiles, compliance policies, app deployment, enrollment restrictions). The tenant-level
**MDM auto-enrollment scope** (Entra ID → Mobility) and **Intune licensing** are tenant/platform concerns.

### Decision
Scope this repo to the **single deployment-time hook** that genuinely belongs with the session hosts:
- `var.intune_enrollment` (default **false**) adds the well-known Intune MDM app ID
  (`0000000a-0000-0000-c000-000000000000`) as `mdmId` on the `AADLoginForWindows` extension, triggering
  auto-enrollment during Entra join. It has no effect unless `entra_id_join = true`.
- Default **off**: enabling it without the tenant MDM scope + licensing in place causes the
  `AADLoginForWindows` extension to fail, so enrollment is opt-in once prerequisites exist.

**Out of scope (control plane):** the Entra MDM auto-enrollment scope, Intune licensing, and all Intune
configuration/compliance/app policies. These are a separate **Intune-as-code** effort (Microsoft Graph /
`microsoft365` provider / Microsoft365DSC), not part of this `azurerm`/AVM application landing zone.

### Consequences
- **Pro:** session hosts can auto-enroll with a single toggle; no scope creep into a Graph-based config
  stack the AVM toolchain doesn't cover; safe default avoids extension failures.
- **Con:** enabling Intune end-to-end still requires out-of-repo tenant configuration (documented as a
  prerequisite); policy/compliance management lives in a separate stack to be defined if needed.

### Alternatives considered
- **Full Intune-as-code in this repo** — rejected: no AVM/`azurerm` coverage; belongs in a dedicated Graph
  stack to avoid mixing provider ecosystems and ownership.
- **Document only, no code** — rejected: the auto-enroll hook is small, host-local, and the natural place
  for it is the session-host extension.

---

## ADR-0007 — Deploys are explicit (workflow_dispatch), not merge-triggered

- **Status:** Accepted
- **Date:** 2026-06-21
- **Deciders:** Project owner + DevSecOps Engineer

### Context
The original CI had `apply-on-merge.yml` auto-running `terraform apply` (prod) on every push to `main`
touching `modules/**`, `envs/**`, `landing-zones/**`, or `.github/workflows/**` (gated by the `production`
GitHub Environment). In practice the deploy cadence is **deliberate and manual** — dev and prod are
mutually exclusive on the PoC subscription (10 vCPU regional cap), so dev is destroyed before each prod
apply. Merge-triggered apply meant routine commits (docs, workflows, config) kept kicking off prod-apply
runs, and "merge = deploy" doesn't match a destroy-first cadence.

### Decision
**Remove `apply-on-merge.yml`.** All applies (and destroys) go through the new **`manual-deploy.yml`**
(`workflow_dispatch`): pick environment (dev|prod) + action (plan|apply|destroy); apply/destroy require a
typed environment-name confirmation; prod apply/destroy run under the `production` Environment gate. PR
plans stay on `plan-on-pr.yml`. The three federated credentials are unchanged and still used:
`pull_request` (plan-on-pr), `main` ref (manual-deploy dev + plan), `environment:production`
(manual-deploy prod apply/destroy).

### Consequences
- **Pro:** every deploy is an explicit, confirmed, gated action; routine pushes to `main` no longer trigger
  prod applies; matches the destroy-first dev↔prod workflow; no duplicate apply paths.
- **Con:** no automatic continuous-deployment on merge (intentional here; revisit if the workflow ever
  shifts to true GitOps CD with non-overlapping environments/quota).

### Alternatives considered
- **Convert `apply-on-merge` to `workflow_dispatch`** — rejected: that just duplicates `manual-deploy`.
- **Keep merge-triggered apply, rely on the env gate** — rejected: still fires (and demands approvals) on
  non-deploy commits; noisy and error-prone.

---

## ADR-0008 — CI bootstrap via `workflow_dispatch` — ephemeral state + deterministic naming

- **Status:** Accepted
- **Date:** 2026-06-24
- **Deciders:** Project owner + Cloud Solutions Architect + DevSecOps Engineer
- **Supplements:** ADR-0002 (bootstrap layer). Does not supersede it — the backend design (GZRS, CMK,
  shared keys disabled, OIDC, IP allow-list) is unchanged. This ADR only changes *how bootstrap is run*
  (a CI workflow) and *how the backend resources are named* (deterministic, not `random_string`).

### Context
ADR-0002 made `bootstrap/` a **one-time, manual, local-state** layer: an operator runs `terraform apply`
on a workstation, then hand-copies the outputs into `envs/{dev,prod}.backend.hcl` and the GitHub repo
variables. Two problems surface in the demo/PoC operating model:

1. **No CI path to re-bootstrap.** `cleanup-demo.yml` (with `include_state_backend = true`) deletes
   `rg-tfstate-avd-001` via `az group delete`. Recreating the backend then requires a human on a
   workstation with the local state file — there is no equivalent of `manual-deploy.yml` for the
   backend itself. The backend is the one thing the demo cannot rebuild from the Actions UI.

2. **Naming is non-reproducible.** The state Storage Account (`sttfstate<suffix>`) and Key Vault
   (`kv-tfstate-<suffix>`) take their suffix from `random_string.suffix`, whose value lives **only in
   bootstrap's local state**. If that state is lost (or bootstrap is re-run on a fresh runner), the
   suffix changes, the new account/vault names no longer match the hardcoded values in
   `envs/{dev,prod}.backend.hcl`, and every consumer's `init` breaks until the files are hand-edited.

The bootstrap state is **not needed for steady-state operation**: teardown is `az group delete` (not
`terraform destroy`), and deploys (`manual-deploy.yml`) reach the Storage Account by name over the data
plane — neither path reads bootstrap's `.tfstate`. The only thing the state carries that matters is the
random suffix, and that is exactly what makes re-bootstrap non-reproducible.

### Decision
**Ephemeral state + deterministic naming**, run from a new `bootstrap.yml` (`workflow_dispatch`):

1. **Bootstrap runs with throwaway (local) state on the GitHub runner; its state is NOT persisted.**
   Each run `init`s a fresh local backend, `apply`s, and discards the runner. Bootstrap does not adopt a
   remote backend (that would reintroduce the chicken-and-egg ADR-0002 calls out).

2. **The suffix becomes a deterministic function of the subscription ID**, replacing
   `random_string.suffix`. Every re-bootstrap against the same subscription produces the **same** names,
   so `envs/*.backend.hcl` stays valid across teardown/rebuild cycles without hand-editing:
   `suffix = substr(sha1(lower(var.subscription_id)), 0, 8)` (8 lowercase hex chars). Adopted by the
   Storage Account (`sttfstate<suffix>`) and the Key Vault (`kv-tfstate-<suffix>`). The Resource Group
   (`rg-tfstate-avd-001`) and container (`tfstate`) are already deterministic.

3. **`envs/{dev,prod}.backend.hcl` are updated once** to the computed Storage Account name and committed,
   becoming a stable contract. The RG name does not change.

4. **`bootstrap.yml` is OIDC-authenticated and gated** identically to `manual-deploy.yml`: it runs under
   the `production` GitHub Environment (required-reviewer) and requires a typed subscription-ID
   confirmation. OIDC subject is `:environment:production`, matched by the existing `github-env-production`
   federated credential — no new federated credential is needed.

5. **The workflow runs the state-backend resources only** (`create_oidc_identity = false`). The OIDC
   identity (app reg / SP / federated creds / subscription RBAC) is **not** re-created by CI — it already
   exists and is reused (the SP is the very identity the workflow authenticates as; it cannot bootstrap
   itself). Backend-only is the same posture as the current live deployment.

### Consequences
- **Pro:** re-bootstrap is a one-click, gated, OIDC, secret-less Action — symmetric with
  `cleanup-demo.yml`. Names are reproducible, so `envs/*.backend.hcl` never drifts after a backend
  rebuild. No local state file to protect or lose. No new federated credential or RBAC surface.
- **Pro:** discarding bootstrap state is safe **in this model** — teardown is `az group delete`, deploys
  use the account by name; neither needs the state. (Validated below.)
- **Con — Key Vault recovery is now load-bearing, not optional.** Key Vault names are **globally unique
  and stay reserved while soft-deleted**, and **purge protection means the vault cannot be purged until
  the retention window elapses** (90 days here) — not even by Microsoft. With a deterministic name, a
  re-bootstrap after `include_state_backend` cleanup will hit the **soft-deleted** `kv-tfstate-<suffix>`.
  This is handled by `recover_soft_deleted_key_vaults = true` (already set in `bootstrap/providers.tf`):
  the provider **recovers** the soft-deleted vault instead of failing. The CI principal must therefore
  hold the recover permission (`Microsoft.KeyVault/locations/deletedVaults/.../recover` — covered by its
  subscription Contributor + the Key Vault data-plane roles bootstrap assigns). Without this flag a
  re-bootstrap would fail with `VaultAlreadyExists` / conflict. This was true under random naming too,
  but random naming usually *dodged* it by minting a new name; deterministic naming guarantees the
  collision, so recovery must work every time.
- **Con — predictable names.** The Storage Account and Key Vault names are now derivable from the
  (non-secret) subscription ID. This is acceptable: auth is **Entra ID / RBAC only** (shared keys
  disabled on the SA, RBAC authorization on the KV), both are **default-Deny firewalled** to the
  deployer/runner IPs, and the names are not secrets. Predictability removes no security control. (It
  marginally aids enumeration, but enumeration without RBAC yields nothing.) SHA1 is used purely as a
  name-shortening hash, not for any security property — not a cryptographic concern.
- **Con — global-uniqueness risk.** An 8-hex-char suffix derived from a 36-char GUID gives 2^32 of the
  hash space; a `sttfstate<8hex>` collision with another tenant's account is astronomically unlikely but
  not impossible. If a run ever fails with `StorageAccountAlreadyTaken`, lengthen the suffix or fold in
  the RG name — see the spec. (`kv-tfstate-<8hex>` = 18 chars, within the 24-char KV limit.)
- **Con — re-bootstrap is not a true `terraform destroy`-able layer.** Because state is discarded, the
  backend can only be torn down out-of-band (`az group delete` via `cleanup-demo.yml`), never by
  `terraform destroy`. Accepted: that is already the only teardown path in this repo.

### Alternatives considered
- **Self-host bootstrap state (persist it remotely).** Give bootstrap its own remote backend (a second,
  manually-created Storage Account, or a separate `tfstate-bootstrap` container). Rejected: reintroduces
  a chicken-and-egg seed account that itself must be bootstrapped, adds a persistent state blob to
  protect, and buys nothing — steady-state ops never read bootstrap state. Determinism makes the suffix
  reproducible without persisting anything.
- **Keep local-only / manual bootstrap (status quo, ADR-0002).** Rejected: no CI re-bootstrap path,
  asymmetric with `cleanup-demo.yml`, and the random suffix breaks `envs/*.backend.hcl` on any state
  loss — the exact failure this ADR removes.
- **Keep `random_string` but persist its output as a GitHub variable.** Rejected: still requires a place
  to store/restore the value and a manual step to wire it; a pure function of the subscription ID needs
  no storage at all.
- **Use Azure's `uniqueString`-style hash of the RG resource ID.** Equivalent idea; the subscription ID
  is the more stable, earlier-known input (the RG ID embeds the same subscription ID plus a fixed name),
  and is available before any resource is created. Folding the RG name in is the documented fallback if a
  collision ever occurs.
