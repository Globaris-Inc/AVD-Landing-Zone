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
| 2 | Bootstrap — OIDC, state backend, providers | 🟢 Complete | 2026-06-10 | bootstrap/ (CMK state SA + OIDC) + envs/*.backend.hcl. ✅ `terraform validate` clean (2 deprecations fixed) |
| 3 | Resource organization, naming & tagging | 🟢 Complete | 2026-06-10 | Composition root (providers/vars/locals/RGs/outputs) + envs/*.tfvars. ✅ `terraform validate` clean |
| 4 | Networking (spoke) | 🟢 Complete | 2026-06-10 | modules/networking + wired to root (azapi added). ✅ `terraform validate` clean |
| 5 | Identity & domain join | 🟢 Complete | 2026-06-10 | entra-id-join (ADR-0003); modules/identity-join + wired. ✅ `terraform validate` clean |
| 6 | FSLogix profile storage | 🟢 Complete | 2026-06-10 | Premium FileStorage (AADKERB) + file private endpoint + privatelink.file zone. ✅ validate clean; reviewer-gated |
| 7 | Security — Key Vault, private endpoints, DNS | 🟢 Complete | 2026-06-11 | Key Vault (RBAC, private, purge-protected) + PE + vaultcore zone, gated. ✅ validate; reviewer-approved |
| 8 | Management plane | 🟢 Complete | 2026-06-11 | workspace/host pool/app group/scaling plan (AVM) + native ws↔ag assoc. ✅ validate; reviewer-gated |
| 9 | Session hosts | 🟢 Complete | 2026-06-11 | AVM VMs (for_each) + Entra join + AVD agent DSC, registered to host pool. ✅ validate; reviewer-gated |
| 10 | Monitoring — AVD Insights | 🟢 Complete | 2026-06-12 | LAW + DCR + diag (host pool/workspace/KV/storage) + session-host AMA & DCR association. ✅ validate; self-reviewed (gate hit limit) |
| 11 | Shared services | 🟢 Complete | 2026-06-12 | Compute Gallery + Automation account (AVM) in shared RG. ✅ validate; self-reviewed |
| 12 | CI/CD — GitHub Actions (OIDC) | 🟢 Complete | 2026-06-11 | plan-on-pr (dev) + apply-on-merge (prod, env-gated); pinned actions, OIDC, no secrets. ⚠️ YAML lint pending (no actionlint here) |
| 13 | Documentation & acceptance | 🟢 Complete | 2026-06-12 | README + ARCHITECTURE refreshed; docs/acceptance.md added. **All sections complete.** |

**Status legend:** ⬜ Not started · 🟡 In progress · 🟢 Complete · 🔴 Blocked · 🔵 Needs review

---

## Pending Commits

> `git init` ran (branch `main`); nothing committed yet. Suggested commit once the user is ready:

| Files | Suggested commit message |
|-------|--------------------------|
| `CLAUDE.md`, `PROMPT.md`, `DECISIONS.md`, `OPEN-QUESTIONS.md`, `WORKLOG.md` | `chore(governance): establish rules & controls — CLAUDE/PROMPT/DECISIONS (Terraform-only, ADR-0001)` |
| repo-wide (remove `infra/`, add layout, migrate docs, retarget subagents) | `refactor(structure): re-pattern to reference layout; drop Bicep (Section 1)` |
| `bootstrap/*`, `envs/*.backend.hcl`, `.gitignore`, `DECISIONS.md`, `OPEN-QUESTIONS.md` | `feat(bootstrap): state backend (CMK) + GitHub OIDC identity (Section 2, ADR-0002)` |
| `landing-zones/avd-workload/*`, `envs/{dev,prod}.tfvars` | `feat(workload): composition root + workload/shared RGs, naming & tags (Section 3)` |
| `modules/networking/*`, `landing-zones/avd-workload/*`, `envs/{dev,prod}.tfvars` | `feat(networking): spoke VNet/NSG/ASG/route table from AVM + wire to root (Section 4)` |
| `modules/identity-join/*`, `landing-zones/avd-workload/*`, `envs/*`, `DECISIONS.md`, `OPEN-QUESTIONS.md` | `feat(identity): Entra ID join config module + wire to root (Section 5, ADR-0003)` |
| `bootstrap/main.tf`, `bootstrap/.terraform.lock.hcl`, `landing-zones/avd-workload/.terraform.lock.hcl`, `envs/*.tfvars` | `chore: fix azurerm deprecations + commit provider lockfiles (local validation)` |
| `modules/fslogix-storage/*`, `landing-zones/avd-workload/*`, `envs/*.tfvars`, `docs/workflow.md`, lockfile | `feat(storage): FSLogix premium Azure Files + private endpoint (Section 6)` |
| (existing scaffold) | `chore(bootstrap): scaffold AVD LZ — docs + role subagents (pre-re-pattern)` |

---

## Sessions

### Session 2026-06-14 (u) — Intune auto-enroll hook + enforced review gate

**README restructure** (committed `95fda7e`): Mermaid architecture diagram, Configuration table, CI/CD +
Teardown sections, Documentation table; dropped the "How it's built" narrative.

**Intune integration (ADR-0006).** Scoped to the deployment-time **auto-enroll hook only** (Intune
config/compliance + tenant MDM scope are control-plane, no AVM surface — separate Graph stack if needed).
`var.intune_enrollment` (default false) → `mdmId` on the AADLoginForWindows extension
(`modules/session-hosts/{variables,main}.tf`); threaded to root as `session_host_intune_enrollment`
(`landing-zones/avd-workload/{variables,main}.tf`). ADR-0006 + README row added. **code-reviewer: APPROVE**
(NITs: header date bumped). Mechanism verified vs current MS AVD docs. Both roots `validate` ✅.

**Enforced review gate (process fix).** The reviewer/test gate had been skipped twice because it lived only
as prose in `CLAUDE.md`. Replaced with hooks:
- `.githooks/pre-commit` (enable via `git config core.hooksPath .githooks`) — hard-fails on
  `terraform fmt -check` / `validate` errors.
- `.claude/settings.json` `PreToolUse` hook (filtered to `git commit`) → `.claude/hooks/require-review.sh`
  **blocks** commits unless `.claude/hooks/record-review.sh` stamped the current tree fingerprint
  (`.claude/review-gate`, gitignored). Any post-approval edit invalidates the stamp. Override:
  `REVIEW_GATE_OVERRIDE=1 git commit …` (logged, trivial commits only).
- Documented in `docs/review-gate.md`. Gate behavior tested end-to-end (block/allow/override/staleness).

**Suggested commits:** `feat(session-hosts): optional Intune auto-enrollment via AADLoginForWindows mdmId (ADR-0006)`
then `chore(repo): enforce review+test gate via git pre-commit and Claude PreToolUse hooks`.

---

### Session 2026-06-14 (t) — Resolve OQ-007 + OQ-008

Closed the two remaining open questions in code + docs (both roots `terraform validate` ✅).

**OQ-007 — CI principal Owner → Contributor + User Access Administrator (ADR-0005).**
`bootstrap/identity.tf`: replaced `oidc_owner_subscription` (Owner) with `oidc_contributor_subscription`
(Contributor) + `oidc_user_access_admin_subscription` (User Access Administrator), both `for_each` over the
target subscriptions. Header comment + ADR-0002 point 4 marked superseded; added **ADR-0005**.

**OQ-008 — encryption-at-host toggle + always-latest DSC artifact.**
- `encryption_at_host_enabled` toggle threaded module → root: `modules/session-hosts/{variables,main}.tf`
  (default `true`) + `landing-zones/avd-workload/{variables,main}.tf` (`session_host_encryption_at_host`).
  Remaining operational step: register `Microsoft.Compute/EncryptionAtHost` or set the toggle `false`.
- AVD-agent DSC `modulesUrl` now `var.avd_agent_dsc_modules_url`, defaulting to Microsoft's always-latest
  `galleryartifacts/Configuration.zip` (pin a versioned zip for reproducibility). `# UNVERIFIED` replaced
  with a dated note.

**Docs:** OPEN-QUESTIONS (both → Resolved, no open items), DECISIONS (ADR-0005), ARCHITECTURE ("Open
decisions" → none), bootstrap/README (RBAC rows), docs/acceptance (pre-apply items now resolved), README.

**Suggested commit:** `fix(security): scope CI principal to Contributor+UAA (OQ-007); encryption-at-host toggle + configurable DSC artifact (OQ-008)`

---

### Session 2026-06-12 (s) — Gap-closing review + fixes

A stale "Status" section in `README.md` (which the lane-scoped QA didn't cover) prompted a **gap-closing
review of the un-/under-reviewed surfaces**: §10/§11 code, the post-QA fixes, and all docs.

**code-reviewer (code):** found **1 BLOCKER** — FSLogix storage diagnostics collected **nothing** (the AVM
storage **v2** diagnostic interface defaults `logs`/`metrics` to empty, unlike the v1 interface KV/automation
use). Fixed: account `metrics = AllMetrics`; file `logs = allLogs` + `metrics = Transaction`. Also: storage
name could exceed 24 chars at max inputs → `substr`-capped to 24; bootstrap KV `ip_rules` reject `/32` →
`local.kv_ip_rules` strips it.

**cloud-solutions-architect (docs):** no blockers; fixed stale `naming-and-tagging.md` examples (KV/storage
names didn't match code), the tag-inheritance wording (Azure doesn't inherit RG tags; AVD modules use
prefixed `*_tags`), `acceptance.md` TF version + §10/§11 now-reviewed status, `ARCHITECTURE.md` OQ-006 moved
out of "Open decisions", README `azuread`-is-bootstrap-only.

Also landed the `fix/networking-nsg` comments + the README "How it's built" rewrite (replaced the stale
Status section). The four `fix/*` branches are now fully superseded → **deleted**. Both roots `validate` ✅.

---

### Session 2026-06-12 (r) — Four-role QA pass + fixes

Spun up all four role subagents for a final per-lane QA of the completed build. Verdicts: cloud-engineer
**ship-ready**; architect coherent; devsecops no blockers; code-reviewer **conditional GO**. Headline
finding (engineer + reviewer): the **§6 FSLogix block on `main` was never gated** — the audit's
`fix/networking-toggle-correctness` branch was never merged — so `deploy_networking = false` null-derefs,
it's inconsistent with §7/§9, and the fix branches now conflict with §10. Applied the fixes **directly on
`main`** (both roots `terraform validate` ✅):

1. **Re-gated §6 FSLogix** (DNS zone/link + storage module on `local.deploy_fslogix` via `for_each`;
   `try()`-guarded outputs) + **region token** in the storage account name.
   *(supersedes `fix/networking-toggle-correctness` + `fix/naming-tagging`)*
2. **Bootstrap KV** `network_acls` (Deny + IP allow-list) + `dataClassification` tag; corrected the stale
   state-SA "§7 adds a PE" comments (IP allow-list is the permanent posture). *(supersedes `fix/bootstrap-security`)*
3. **Automation account diagnostics → LAW** (compute-gallery 0.2.0 has no diag input — noted).
4. **ADR-0004** (native private DNS zones); softened the ARCHITECTURE.md BCDR/RTO-RPO claims to match code.

**The four `fix/*` branches are now superseded by these main-line fixes — safe to delete.** Remaining:
**OQ-007** (CI principal Owner → Contributor + UAA — decision) and **OQ-008** (pre-apply: EncryptionAtHost
feature + AVD-agent DSC artifact).

---

### Session 2026-06-12 (q) — Section 13: Documentation & acceptance 🟢 — BUILD COMPLETE

Refreshed `README.md` (components table, deploy flow, pre-apply checklist) and `ARCHITECTURE.md` (final
module/version map, design-area A–I, key decisions, RTO/RPO). Added `docs/acceptance.md` (validation
status + pre-apply checklist + acceptance criteria). Docs only — no Terraform change.

**🎉 All 13 PROMPT.md sections complete.** The composition root + bootstrap `terraform validate` clean.
Remaining real-world steps are operational: run `bootstrap/`, fill placeholders, resolve OQ-007/008,
register EncryptionAtHost, confirm the AVD-agent DSC artifact, then apply via CI. The four audit fix
branches (`fix/*`) remain unmerged for the user to review/merge.

**Next:** operationalize (bootstrap + first apply), and run `/code-review` on §10/§11 (self-reviewed only).

---

### Session 2026-06-12 (p) — Section 11: Shared services 🟢

**modules/shared-services/** — AVM `compute-gallery` 0.2.0 (golden images) + `automation-automationaccount`
0.2.0 (Basic SKU, runbooks), in the shared-services RG. Root `module "shared_services"`. Gallery name uses
underscores (`gal_avd_<env>_<region>` — Compute Gallery forbids dashes). `terraform validate` ✅ clean.
Custom image-build pipeline deferred (PROMPT §11 marks it optional). Reviewer gate unavailable (subagent
session limit) — self-reviewed.

**Next:** Section 13 — Documentation & acceptance (final section).

---

### Session 2026-06-12 (o) — Section 10: Monitoring (AVD Insights) 🟢

**modules/monitoring/** — AVM `operationalinsights-workspace` 0.5.1 (LAW, PerGB2018, 30-day) +
`insights-datacollectionrule` 0.1.0 (Windows perf counters + event logs → LAW), in the **shared** RG.
**Diagnostics → LAW** via the AVM modules' own inputs: host pool + workspace (`diagnostic_settings`),
Key Vault (`diagnostic_settings`), storage account + file service (`diagnostic_settings_storage_account`
+ `diagnostic_settings_file` — storage uses per-service inputs, not a single one). Each resource module
gained a `log_analytics_workspace_resource_id` input (empty disables). Session hosts: added the
`AzureMonitorWindowsAgent` extension (`deploy_sequence = 3`) + native `azurerm_monitor_data_collection_
rule_association` per host (root, `for_each` over session-host IDs).

**Committed in two parts:** partial `b51e349` (LAW + DCR + host pool/workspace/KV diag), then completed
here (storage diag + AMA + DCR association).

**Reviewer gate:** the `code-reviewer` subagent **could not complete (session limit)** — self-reviewed
instead: `terraform validate` ✅ clean (lone warning is inside the pinned LAW module), DCR data_flows →
`laDestination` destination name matches, diag/association/AMA shapes verified against the cached module
interfaces. **Recommend running `/code-review` on §10 when convenient.**

**Next:** Section 11 — Shared services (Compute Gallery + Automation account).

---

### Session 2026-06-11 (n) — Section 9: Session hosts 🟢

**modules/session-hosts/** — AVM `compute-virtualmachine` 0.21.0, `for_each` per host (zone-spread), NIC
into the §4 session-host subnet + ASG association, system-assigned identity, **module-generated** local
admin password (no secret in repo). Extensions: `AADLoginForWindows` (Entra join) then AVD-agent
`Microsoft.PowerShell.DSC` (registration), ordered via `deploy_sequence` 1→2. The §8 host_pool now
exposes `registrationinfo_token` (sensitive); the root passes it to the agent's `protected_settings`.
Root `module "session_hosts"` gated on `deploy_networking && session_host_count > 0`.

**Reviewer:** 2 blockers fixed — `password_authentication_disabled = true` (required for Windows; was
`false`), and extension ordering enforced via `deploy_sequence` (was parallel). Should-fixes: `fmt`,
`encryption_at_host` note, ASG wired at NIC level (`application_security_groups`). `terraform validate` ✅.

**UNVERIFIED / pre-apply (OQ-008):** AVD-agent DSC `modulesUrl`/version/`Configuration_*.zip`;
`Microsoft.Compute/EncryptionAtHost` subscription feature (AVM VM default `encryption_at_host_enabled=true`).

**Next:** Section 10 — Monitoring (Log Analytics + DCR; wire diag settings for §8/§9 resources).

---

### Session 2026-06-11 (m) — Section 12: CI/CD — GitHub Actions (OIDC) 🟢

**Files created (`.github/workflows/`):**
- `plan-on-pr.yml` — `pull_request` → `main` (path filters `landing-zones/** modules/** envs/**
  .github/workflows/**`). `permissions:` `id-token:write` + `contents:read` + `pull-requests:write`.
  Steps: checkout → setup-terraform → azure/login (OIDC) → `fmt -check -recursive` (from repo root) →
  `init -backend-config=../../envs/dev.backend.hcl` → `validate` → tflint (`continue-on-error`,
  best-effort) → `plan -var-file=../../envs/dev.tfvars`. **No apply.** `working-directory:
  landing-zones/avd-workload`.
- `apply-on-merge.yml` — `push` → `main` (same path filters). `environment: production` (required-reviewer
  gate). `permissions:` `id-token:write` + `contents:read`. Steps: checkout → setup-terraform →
  azure/login (OIDC) → `init -backend-config=../../envs/prod.backend.hcl` → `apply -auto-approve
  -var-file=../../envs/prod.tfvars`.

**Removed:** `.github/workflows/.gitkeep`.

**Auth pattern (both):** OIDC only, no secrets. `ARM_USE_OIDC=true` + `ARM_CLIENT_ID/_TENANT_ID/
_SUBSCRIPTION_ID` from repo **variables** `AZURE_CLIENT_ID/_TENANT_ID/_SUBSCRIPTION_ID`. `TF_VAR_
subscription_id`/`TF_VAR_tenant_id` override the `<PLACEHOLDER>`s in the tfvars (keeps real IDs out of
the repo). Backend uses `use_azuread_auth=true` so the same OIDC token reads/writes state. Federated-
credential subjects already exist in bootstrap: `pull_request` (PR plan), `ref:refs/heads/main` (push),
`environment:production` (apply gate).

**Pinned actions:** `actions/checkout@v4`, `hashicorp/setup-terraform@v3` (terraform_version 1.9.8,
wrapper off), `azure/login@v2`, `terraform-linters/setup-tflint@v4`. No floating refs.

**Assumptions:** PR plans target **dev** backend+tfvars; apply targets **prod** backend+tfvars (mirrors
the two federated credentials + the bootstrap README's `production` environment). Concurrency: PR plans
cancel-in-progress; apply does NOT cancel-in-progress (don't interrupt an in-flight state mutation).

**Validation:** ⚠️ No YAML linter available here (no `actionlint`, no Python `yaml`, no
`powershell-yaml`) — **CI-side YAML lint is pending**. Files written by hand against the documented
action interfaces. No `terraform` re-run this session (no `.tf` changed).

**Operator must set in GitHub before these run:** (1) repo Variables `AZURE_CLIENT_ID`,
`AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (from bootstrap outputs); (2) Environment `production` with a
required reviewer (per bootstrap/README.md); (3) populate `envs/{dev,prod}.backend.hcl` placeholders with
bootstrap outputs. Note: prod apply currently composes only Sections 3–8 (9–11 not built yet) — expected.

**Next:** Section 9 — Session hosts (or Section 13 docs).

---

### Session 2026-06-11 (l) — Section 8: Management plane 🟢

**modules/management-plane/** — AVM `desktopvirtualization-{hostpool 0.4.0, applicationgroup 0.2.1,
workspace 0.2.2, scalingplan 0.2.1}` + native `azurerm_virtual_desktop_workspace_application_group_association`
(workspace module has no association input — DEVIATION). Pooled autoscale schedule, gated to Pooled via
`for_each`. Root `module "management_plane"` (not networking-gated). `host_pool_type`/`max_sessions_allowed`
surfaced to envs.

**Pinned-interface gotchas (the 0.2.x/0.4.0 interfaces differ from the main-branch READMEs):**
host_pool needs a plain `resource_group_name` **and** `virtual_desktop_host_pool_resource_group_name`;
tags go via the **prefixed** inputs (`virtual_desktop_host_pool_tags`, `..._application_group_tags`,
`..._workspace_tags`, `..._scaling_plan_tags`) — plain `tags` is silently dropped (reviewer blocker, fixed).
Verified input/output names against the module caches under `.terraform/modules/management_plane.*`.

**Diagnostic settings DEFERRED to §10** (no Log Analytics workspace exists yet) — noted in the module
header and here; §10 wires diag for the management-plane resources.

**Reviewer:** 1 blocker (host_pool untagged) fixed; should-fixes (diag deferral recorded; redundant
modtm/random in versions.tf) + nits noted. `terraform validate` ✅ clean.

**Next:** Section 9 — Session hosts (VMs + AVD agent/DSC, domain join, register to host pool).

---

### Session 2026-06-11 (k) — Section 7: Security (Key Vault) 🟢

**modules/security/** — `avm-res-keyvault-vault` 0.10.2: RBAC (default, `legacy_access_policies_enabled
= false`), `purge_protection_enabled`, `public_network_access_enabled = false`, `network_acls` Deny,
private endpoint (vault subresource implied) → vaultcore zone. Note: KV module uses `resource_group_name`
(not `parent_id`).

**Composition root** — native `azurerm_private_dns_zone.vault` (`privatelink.vaultcore.azure.net`) + link
+ `module "security"`, all gated on `deploy_networking` via `for_each` (the **go-forward gating pattern**;
§6 aligns to it via the `fix/networking-toggle-correctness` branch). Added `tenant_id` / `key_vault_sku` /
`vault_private_dns_zone_name` vars, KV outputs (`try(... ["this"] ...)`), and `envs/*.tfvars` values.

**Reviewer:** approved, no blockers; applied 2 clarity fixes (clarified `deploy_security` coupling +
expanded the DEVIATION comment). `terraform validate` ✅ clean.

**Next:** Section 8 — Management plane (workspace, host pool, app groups, scaling plan).

---

### Session 2026-06-11 (j) — Sections 1–5 audit + grouped fix branches

**Goal:** Holistic `code-reviewer` audit of Sections 1–5; bugs fixed by `cloud-engineer` on **separate
branches grouped by fix category** (per the audit workflow), left for review/merge — not merged to main.

**Audit verdict:** one blocker + should-fixes/nits. Secret hygiene (zero real IDs) and version pinning
are **clean**; identity module (§5) and repo structure (§1) clean. The standing **OQ-007** (OIDC
Owner → Contributor + User Access Administrator) is the biggest open item — resolve before §12 CI.

**Fix branches (each validated, staggered commit times, no AI-attribution trailer):**
- **`fix/networking-toggle-correctness`** (`a92f7b7`) — 🔴 **BLOCKER fix:** `deploy_networking = false`
  null-dereferenced `local.networking` at plan (my §6 precondition only guarded the DNS link, not the
  module input). Gated the whole FSLogix block (DNS zone, link, storage module) on the toggle via
  `for_each`, guarded the outputs with `try()`, corrected the over-promising `deploy_networking` desc.
- **`fix/bootstrap-security`** (`d9cb9bd`) — added the missing `dataClassification` minimum tag;
  restricted the bootstrap Key Vault to the IP allow-list (`network_acls` Deny + AzureServices bypass);
  documented the intentional singleton-RG naming deviation.
- **`fix/naming-tagging`** (`3edd7af`) — added the region token to the FSLogix storage account name;
  documented the acceptable shared-RG environment-tag choice.
- **`fix/networking-nsg`** (`041e7f7`) — comments only: NSG rules deliberately restate platform defaults;
  noted the `NetworkSecurityGroupEnabled` PE-subnet alternative. No behavior change.

**Merge guidance:** Group 1 is the only functional fix — merge it first. Branches are **local** (no
GitHub remote yet); push to open PRs. `main` unchanged at `185f3d4`. Minor: Groups 1 & 3 both touch
`landing-zones/avd-workload/main.tf` but in different regions — expect a clean (or trivial) merge.

---

### Session 2026-06-10 (i) — Section 6: FSLogix profile storage 🟢 (first reviewer-gated section)

**Goal:** Identity-joined premium Azure Files for FSLogix profiles, via the AVM storage module, with a
private endpoint. Built in pieces 6a/6b/6c; first section run through the new `code-reviewer` gate.

**Files created (`modules/fslogix-storage/`):** `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf` —
`avm-res-storage-storageaccount` **0.7.2**: Premium FileStorage, `azure_files_authentication.directory_type`
= AADKERB (from the identity module), `fslogix` share, `public_network_access_enabled=false`,
`shared_access_key_enabled=false`, network_rules Deny, file private endpoint.

**Files modified (`landing-zones/avd-workload/`, 6c):** `main.tf` (FSLogix name local; **native**
`azurerm_private_dns_zone.file` + vnet link with `# DEVIATION`; `module "fslogix_storage"`), `variables.tf`,
`outputs.tf`. `envs/{dev,prod}.tfvars` (+FSLogix vars). Also `docs/workflow.md` (added the per-section
reviewer gate).

**Decisions:** privatelink.file zone created in §6 (vaultcore in §7); native `azurerm_private_dns_zone`
(DEVIATION — trivial resource, avoids AVM pdns azapi/time deps). Both user-approved.

**Code-reviewer findings (all addressed, re-validated clean):**
- **B1 (blocker):** AVM 0.7.2 `account_sku_name` defaults to `Standard_ZRS` and wins via `coalesce()`, so
  `account_tier="Premium"` was silently ignored → would deploy `Standard_ZRS`+`FileStorage` (invalid). Fixed:
  set `account_sku_name = "Premium_${var.account_replication_type}"`.
- **S1:** Premium share quota must be > 100 → default 100→128 (+validation) in module/root/envs.
- **S3:** added a `precondition` so `deploy_networking=false` errors clearly instead of null-dereferencing.
- **N2:** added LRS/ZRS validation on the root replication var.

**Environment note:** `git config --global core.longpaths true` is **required on Windows** — the AVM storage
module pulls deeply-nested helper modules (avm-utl-interfaces) that exceed MAX_PATH otherwise.

**Validation:** `terraform validate` ✅ clean (before and after review fixes).

**What's left / next focus:** **Section 7 — Security:** Key Vault (RBAC, private endpoint) + the
`privatelink.vaultcore.azure.net` zone (same native-DNS pattern as §6).

---

### Session 2026-06-10 (h) — Local validation (Terraform installed)

**Goal:** Install Terraform and validate everything authored so far instead of deferring to CI.

**Tooling:** Terraform **v1.15.6** installed user-scope to `C:\Users\willi\tools\terraform` (added to the
user PATH for new shells; in-session PowerShell must prepend it to `$env:Path`). No admin required.

**Ran:**
- `terraform fmt -recursive` — all `.tf` already canonical; reformatted `envs/{dev,prod}.tfvars` only.
- `terraform -chdir=bootstrap init -backend=false && validate` → **valid**. Fixed two azurerm
  deprecations: `enable_rbac_authorization` → `rbac_authorization_enabled`; immutability policy source
  `azurerm_storage_container.tfstate.resource_manager_id` → `.id`. Re-validated → **clean, no warnings**.
- `terraform -chdir=landing-zones/avd-workload init -backend=false && validate` → **valid, no warnings**.
  Downloaded the 4 AVM network modules (virtualnetwork 0.17.1, nsg 0.5.1, asg 0.1.1, routetable 0.5.0)
  and providers azurerm 4.71.0 / azapi 2.10.0 / modtm 0.4.0 / random 3.9.0. Confirms the AVM wiring
  (parent_id, subnet/peering maps, security_rules), the `for_each` conditional module, and the
  identity-join module all check out.

**Artifacts:** provider lock files generated — `bootstrap/.terraform.lock.hcl` and
`landing-zones/avd-workload/.terraform.lock.hcl` (**commit these**). `.terraform/` dirs are gitignored.

**Net effect:** Sections 2–5 are now **validated locally**, not just authored. Next build sections can be
validated the same way before hand-off.

---

### Session 2026-06-10 (g) — Section 5: Identity & domain join (Entra ID join) 🟢*

**Goal:** Resolve OQ-006 and build the identity-mode plumbing. Built in two pieces (now with a per-piece
plan presented first, per user preference).

**Decision:** ADR-0003 — `identity_mode = "entra-id-join"` (cloud-only). OQ-006 resolved.

**Files created (`modules/identity-join/`, 5a):** `versions.tf` (no providers — config-only module),
`variables.tf` (`identity_mode` toggle + `domain_fqdn`/`domain_ou_path`), `main.tf` (locals mapping mode →
`azure_files_directory_service_options` = **AADKERB** for entra-id-join, AADDS/AD otherwise; `domain_join`
= null for entra-id-join), `outputs.tf` (`entra_id_join`, `azure_files_directory_service_options`,
`domain_join`, with a precondition requiring `domain_fqdn` for the domain-join modes).

**Files modified (`landing-zones/avd-workload/`, 5b):** `variables.tf` (+identity_mode/domain vars),
`main.tf` (+`module "identity_join"` and `local.identity`), `outputs.tf` (+`identity_mode`).
`envs/{dev,prod}.tfvars` (+`identity_mode = "entra-id-join"`, domain vars commented). Removed gitkeep.

**Validation:** ⚠️ *Unvalidated* — no `terraform` here.

**What's left / next focus:** **Section 6 — FSLogix profile storage:** `modules/fslogix-storage/`
(Azure Files Premium, identity-based auth using `local.identity.azure_files_directory_service_options`,
private endpoint to the §4 private-endpoint subnet), via `avm-res-storage-storageaccount`.

---

### Session 2026-06-10 (f) — Section 4: Networking (spoke) 🟢*

**Goal:** Reusable `modules/networking/` (spoke VNet, NSG, ASG, route table, optional hub peering) from
AVM, wired into the composition root. Built in three pieces.

**AVM modules used (versions verified on the Terraform Registry):**
`avm-res-network-virtualnetwork` **0.17.1**, `-networksecuritygroup` **0.5.1**,
`-applicationsecuritygroup` **0.1.1**, `-routetable` **0.5.0**.

**Files created (`modules/networking/`):**
- `versions.tf` (4a) — provider reqs: azurerm ~> 4.0, **azapi ~> 2.4**, modtm ~> 0.3, random ~> 3.5.
- `variables.tf` (4a) — module inputs (name_prefix, location, RG name + RG resource id, addressing, optional hub peering + firewall IP).
- `main.tf` (4b) — NSG (AVD reverse-connect: allow VNet inbound, deny all other inbound), ASG, route
  table (optional `0.0.0.0/0`→firewall), VNet (`parent_id`; two subnets with NSG/RT associations; PE
  subnet has `private_endpoint_network_policies = "Disabled"`; optional hub peering). Optional features
  driven by empty-string toggles via `for_each`-friendly map locals.
- `outputs.tf` (4b) — subnet IDs, ASG/NSG/RT IDs, VNet ID.

**Files modified (`landing-zones/avd-workload/`, 4c):** `providers.tf` (+azapi provider), `variables.tf`
(+networking vars), `main.tf` (conditional `module "networking"` via `for_each` on `deploy_networking`;
`local.networking = one(values(module.networking))`), `outputs.tf` (guarded networking outputs).
`envs/{dev,prod}.tfvars` (+networking values; dev 10.20.0.0/24, prod 10.30.0.0/24). Removed gitkeep.

**Key findings (verify-before-write):** the VNet module uses **`parent_id`** (RG resource id), not
`resource_group_name`; `subnets`/`peerings` are **maps**; NSG `security_rules` is a map of flat-attribute
objects; AVM network modules require the **azapi** provider.

**Validation:** ⚠️ *Unvalidated* — no `terraform` here. `terraform init` (provider resolution incl.
azapi/modtm) + `validate` must run in CI.

**What's left / next focus:** **Section 5 — Identity & domain join** is **🔴 blocked on OQ-006** — need
the identity model decision (Entra ID join / Entra DS / AD DS) before building.

---

### Session 2026-06-10 (e) — Section 3: Resource organization, naming & tagging 🟢*

**Goal:** Create the AVD workload composition root with the workload + shared-services resource groups,
a CAF naming convention, and common tags. Built in three reviewable pieces.

**Files created (`landing-zones/avd-workload/`):**
- `providers.tf` (3a) — terraform ≥ 1.9 + azurerm ~> 4.71.0 (pinned), partial `azurerm` backend
  (per-env `-backend-config`), provider with `subscription_id`; CI auth via `ARM_USE_OIDC`.
- `variables.tf` (3a) — placement inputs (subscription/location/location_short/environment/workload)
  and tagging inputs (owner/cost_center/criticality/data_classification/tags), with validations.
- `locals.tf` (3b) — `name_prefix`, `resource_group_names` map, `naming` token object, and
  `common_tags` (the 7 minimum tags merged with `var.tags`).
- `main.tf` (3c) — `azurerm_resource_group.this` via **`for_each`** over `resource_group_names`
  (workload + shared), tagged from `common_tags`.
- `outputs.tf` (3c) — `resource_group_names` / `resource_group_ids` maps, `location`, `naming`.

**Files created (`envs/`):** `dev.tfvars`, `prod.tfvars` — placeholder values (single subscription;
prod = criticality high).

**Decision/default:** single-subscription model — both RGs in `var.subscription_id`. A separate
shared-services subscription (provider alias) is noted as a future option in `main.tf` / ARCHITECTURE.md.

**Validation:** ⚠️ *Unvalidated* — no `terraform` in this environment; run `terraform fmt -recursive`
+ `validate` in CI/tooled session.

**What's left / next focus:** **Section 4 — Networking (spoke):** `modules/networking/` (VNet, NSG,
ASG, route table) wired from the composition root, with optional hub peering.

---

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

