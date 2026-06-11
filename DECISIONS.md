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
