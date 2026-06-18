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
