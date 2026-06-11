# WORKLOG.md — Session History

> **This file is the source of truth for what's been done.**
> Read at the start of every session; append during/after work. Newest entries at the top.
> Do not delete prior entries — strike through with `~~text~~` if superseded.

---

## Section Status Tracker (per PROMPT.md)

| # | Section | Status | Last Touched | Notes |
| --- | ------- | ------ | ------------ | ----- |
| — | Rules & controls (CLAUDE.md, PROMPT.md, DECISIONS.md) | 🟢 Complete | 2026-06-10 | Governance established; ADR-0001 |
| 1 | Repository Structure (re-pattern + drop Bicep) | 🟢 Complete | 2026-06-10 | Bicep removed; reference layout created; docs migrated to root |
| 2 | Bootstrap — OIDC, state backend, providers | 🟢 Complete* | 2026-06-10 | bootstrap/ (CMK state SA + OIDC) + envs/*.backend.hcl. *Unvalidated — no terraform in env; run fmt/validate in CI |
| 3 | Resource organization, naming & tagging | ⬜ Next | — | Composition root + naming/tagging locals |
| 4 | Networking (spoke) | ⬜ Not started | — | |
| 5 | Identity & domain join | ⬜ Not started | — | Blocked on OQ-006 (identity model) |
| 6 | FSLogix profile storage | ⬜ Not started | — | |
| 7 | Security — Key Vault, private endpoints, DNS | ⬜ Not started | — | |
| 8 | Management plane | ⬜ Not started | — | |
| 9 | Session hosts | ⬜ Not started | — | |
| 10 | Monitoring — AVD Insights | ⬜ Not started | — | |
| 11 | Shared services | ⬜ Not started | — | |
| 12 | CI/CD — GitHub Actions (OIDC) | ⬜ Not started | — | |
| 13 | Documentation & acceptance | ⬜ Not started | — | |

**Status legend:** ⬜ Not started · 🟡 In progress · 🟢 Complete · 🔴 Blocked · 🔵 Needs review

---

## Pending Commits

> `git init` ran (branch `main`); nothing committed yet. Suggested commit once the user is ready:

| Files | Suggested commit message |
|-------|--------------------------|
| `CLAUDE.md`, `PROMPT.md`, `DECISIONS.md`, `OPEN-QUESTIONS.md`, `WORKLOG.md` | `chore(governance): establish rules & controls — CLAUDE/PROMPT/DECISIONS (Terraform-only, ADR-0001)` |
| repo-wide (remove `infra/`, add layout, migrate docs, retarget subagents) | `refactor(structure): re-pattern to reference layout; drop Bicep (Section 1)` |
| `bootstrap/*`, `envs/*.backend.hcl`, `.gitignore`, `DECISIONS.md`, `OPEN-QUESTIONS.md` | `feat(bootstrap): state backend (CMK) + GitHub OIDC identity (Section 2, ADR-0002)` |
| (existing scaffold) | `chore(bootstrap): scaffold AVD LZ — docs + role subagents (pre-re-pattern)` |

---

## Sessions

### Session 2026-06-10 (d) — Section 2: Bootstrap (OIDC + state backend) 🟢*

**Goal:** Stand up the one-time bootstrap — Terraform remote-state backend and GitHub Actions OIDC
identity — mirroring the validated `Azure-Architecture` pattern, adapted for an application LZ.

**Files created:** `bootstrap/{providers,main,identity,variables,outputs}.tf`,
`bootstrap/terraform.tfvars.example`, `bootstrap/README.md`, `envs/dev.backend.hcl`,
`envs/prod.backend.hcl`. Removed `bootstrap/.gitkeep`, `envs/.gitkeep`.

**Files modified:** `.gitignore` (ignore `bootstrap/terraform.tfvars`, `*.secret.tfvars`; note that
`.terraform.lock.hcl` IS committed), `DECISIONS.md` (ADR-0002), `OPEN-QUESTIONS.md` (OQ-007).

**What it builds:** RG + user-assigned identity + CMK Key Vault + RSA key + GZRS Storage Account
(CMK, versioning, shared-keys disabled, container immutability) for remote state; Entra app + SP with
**three** federated credentials (`main`, `pull_request`, `production` environment) and no secret;
RBAC = **Owner on the AVD subscription(s)** via `for_each` (workload + optional shared) plus Storage
Blob Data Contributor for SP and deployer.

**Decisions:** ADR-0002 (bootstrap design). **Adaptation from the reference:** RBAC scoped to the
**subscription**, not the Tenant Root MG (MGs are platform/out-of-scope).

**Providers pinned:** azurerm ~> 4.71.0, azuread ~> 3.8.0, random ~> 3.8.1, time ~> 0.13.1 (mirroring
the validated sibling repo). `# DEVIATION` comments: temporary public access on the state SA (until §7
Private Endpoint); unlocked container immutability.

**Open questions:** OQ-007 — reduce CI principal from Owner to Contributor + User Access Administrator?

**Validation:** ⚠️ *Unvalidated* — no `terraform` in this environment. Authored to mirror the validated
reference; run `terraform fmt -recursive` + `terraform validate` in a tooled session/CI before apply.

**What's left / next focus:** **Section 3 — Resource organization, naming & tagging:** create the
composition root `landing-zones/avd-workload/` (providers + backend partial-config wiring) and the
naming/tagging `locals`.

---

### Session 2026-06-10 (c) — Section 1: Repository Structure 🟢

**Goal:** Re-pattern the repo to the `Azure-Architecture` layout and remove the dropped Bicep stack
(scaffolding only — no module logic).

**Removed:** `infra/` (entire Bicep stack), `docs/architecture.md` (→ root `ARCHITECTURE.md`),
`docs/decisions/` (→ root `DECISIONS.md`).

**Created (layout, `.gitkeep` placeholders):** `bootstrap/`, `envs/`, `landing-zones/avd-workload/`,
`policies/`, `.github/workflows/`, and `modules/{networking,identity-join,fslogix-storage,security,
management-plane,session-hosts,monitoring,shared-services}/`.

**Created/migrated docs:** root `ARCHITECTURE.md` (design-area A–I → Terraform AVM module mapping).

**Updated:** `README.md` (Terraform-only + new layout), `docs/workflow.md`, `docs/naming-and-tagging.md`
(dropped Bicep/parity language), all four `.claude/agents/*` subagents (Terraform-only, new folder
ownership, section-per-section discipline), `.editorconfig` / `.gitignore` / `.claude/settings.json`
(removed Bicep entries).

**Validation:** `terraform fmt`/`validate` — **N/A** this section (no `.tf` files yet; structure only).
Remaining `bicep`/`infra` mentions are intentional records of the *decision* (CLAUDE/PROMPT/DECISIONS/
OPEN-QUESTIONS/WORKLOG history) — no stale config or code references remain.

**Decisions:** none new (executes ADR-0001).

**What's left / next focus:** **Section 2 — Bootstrap (OIDC, state backend, providers):** author
`bootstrap/` Terraform (Entra app + federated creds, state storage account), `providers.tf` version
pins (`terraform >= 1.9`, `azurerm >= 4.0`, `azuread >= 3.0`), and `envs/*.backend.hcl`.

---

### Session 2026-06-10 (b) — Rules & controls established

**Goal:** Per user direction, set up project rules & controls modeled on `../Azure-Architecture`, and
resolve the open structural questions, before resuming the build.

**Decisions (ADR-0001):** Terraform + AVM **only** (drop Bicep — reverses earlier "both"); compose from
published AVM resource modules; **re-pattern** to the reference layout; GitHub Actions + OIDC; **keep**
the four role subagents within a section-per-session model.

**Files created/modified:**
- `CLAUDE.md` — rewritten as the operating-rules contract (was a project guide).
- `PROMPT.md` — new: 13-section AVD landing zone spec.
- `DECISIONS.md` — new: ADR-0001.
- `OPEN-QUESTIONS.md` — resolved OQ-001/002/003/004/005; OQ-006 (identity model) still open.
- `WORKLOG.md` — this entry; tracker switched to PROMPT.md sections.

**Open questions:** OQ-006 — identity model (Entra ID join / Entra DS / AD DS) for the baseline.

**What's left / next focus:** **Section 1 — Repository Structure**: remove `infra/bicep/`, create the
reference layout (`bootstrap/ envs/ modules/ landing-zones/ policies/`), migrate `docs/` ADR into
`DECISIONS.md`, and update the subagents/docs to drop Bicep parity language.

---

### Session 2026-06-10 (a) — Bootstrap scaffold (later superseded by the re-pattern decision)

**Goal:** Bootstrap an AVD LZ repo: both Bicep + Terraform from AVM, GitHub Actions (OIDC), four role
subagents + workflow doc.

**Files created:** `README.md`, `CLAUDE.md` (project-guide style — since rewritten), `.gitignore`,
`.editorconfig`, `.claude/settings.json`, `.claude/agents/{cloud-solutions-architect,cloud-engineer,
devsecops-engineer,code-reviewer}.md`, `docs/workflow.md`, `docs/architecture.md`,
`docs/naming-and-tagging.md`, `docs/decisions/0001-iac-and-modules.md`, `infra/bicep/bicepconfig.json`,
`infra/bicep/main.bicep`, and `infra/bicep/modules/{monitoring,networking,security,storage-fslogix,
management-plane}.bicep`.

**~~Not done~~ / now obsolete:** the remaining Bicep modules, parameters, and the Bicep stack as a whole
are **dropped** per ADR-0001. `infra/bicep/` is removed in Section 1. The pinned AVM version matrix in
`docs/decisions/0001-iac-and-modules.md` remains a useful reference (maps to `Azure/avm-res-*/azurerm`).

**AVM versions pinned:** see `docs/decisions/0001-iac-and-modules.md`.

**Verification:** ⚠️ Unverified — no `az`/`bicep`/`terraform`/`pwsh`/`actionlint` in this environment.
