# OPEN-QUESTIONS.md — Unresolved Items Needing User Input

> Claude writes here when blocked or when an ambiguity needs a user decision. Resolve items by editing
> the **Resolution** line and moving the entry to "Resolved". Newest at the top.

---

## Open

### OQ-008 — Session-host pre-apply prerequisites (§9)
Before the first session-host apply: (1) register `Microsoft.Compute/EncryptionAtHost` on the
subscription — the AVM VM module defaults `encryption_at_host_enabled = true`, so apply fails without it;
(2) confirm the AVD-agent DSC extension `modulesUrl` + `Configuration_*.zip` artifact + DSC
`type_handler_version` against current Microsoft AVD docs (marked `# UNVERIFIED` in
`modules/session-hosts/main.tf`).
**Resolution:** _pending_

### OQ-007 — Scope down the CI principal from Owner?
The bootstrap grants the OIDC service principal **Owner** on the AVD subscription(s) because the
application landing zone creates **role assignments** (AVD/storage RBAC), which Contributor cannot do.
**Question:** Reduce to **Contributor + User Access Administrator** at subscription scope, or keep Owner?
If reducing, confirm whether any resource needs broader rights. (See DECISIONS.md ADR-0002, `bootstrap/identity.tf`.)
**Resolution:** _pending_

---

## Resolved

### OQ-006 — Identity model for session hosts → **Microsoft Entra ID join**
**Resolution (2026-06-10):** `identity_mode = "entra-id-join"` (cloud-only). Session hosts Entra-joined via
the `AADLoginForWindows` extension; FSLogix Azure Files uses Entra Kerberos (`AADKERB`). No DCs deployed
here. Toggle retained for `entra-ds`/`ad-ds`. See DECISIONS.md ADR-0003.

### OQ-001 — Align this repo to the `Azure-Architecture` pattern? → **YES, re-pattern**
**Resolution (2026-06-10):** Re-pattern to the reference layout (root governance docs + `bootstrap/
envs/ modules/ landing-zones/ policies/` + `.github/workflows/{plan-on-pr,apply-on-merge}`). Executed in
Section 1. See DECISIONS.md ADR-0001 and PROMPT.md §1.

### OQ-002 — Terraform-only vs both Bicep + Terraform? → **Terraform only; drop Bicep**
**Resolution (2026-06-10):** Standardize on Terraform + AVM. The partial Bicep stack under `infra/bicep/`
is removed in Section 1. Reverses the earlier "both" choice. See ADR-0001.

### OQ-003 — Replace `CLAUDE.md` with an operating-rules contract? → **YES**
**Resolution (2026-06-10):** `CLAUDE.md` rewritten as the operating-rules contract (section-per-session,
verify-before-write, version pinning, no speculative building, stop-and-ask), modeled on the reference.

### OQ-004 — Author a sectioned `PROMPT.md`? → **YES (draft authored)**
**Resolution (2026-06-10):** `PROMPT.md` authored with 13 sections (Repo structure → Acceptance). User to
review/edit; it is the read-only requirements reference thereafter.

### OQ-005 — Keep the four role subagents? → **KEEP**
**Resolution (2026-06-10):** The four subagents are kept and operate within the section-per-session model.
