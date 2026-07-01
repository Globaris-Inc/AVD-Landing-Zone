# OPEN-QUESTIONS.md — Unresolved Items Needing User Input

> Claude writes here when blocked or when an ambiguity needs a user decision. Resolve items by editing
> the **Resolution** line and moving the entry to "Resolved". Newest at the top.

---

## Open

_None._

---

## Resolved

### OQ-008 — Session-host pre-apply prerequisites (§9) → **toggle + always-latest DSC artifact**
**Resolution (2026-06-14):** (1) Encryption-at-host is now an explicit toggle,
`var.session_host_encryption_at_host` → `encryption_at_host_enabled` (default `true`). The one remaining
operational step is registering `Microsoft.Compute/EncryptionAtHost` on the subscription
(`az feature register --namespace Microsoft.Compute --name EncryptionAtHost`) **or** setting the toggle
`false` if it isn't registered. (2) The AVD-agent DSC `modulesUrl` now defaults to Microsoft's
always-latest `galleryartifacts/Configuration.zip` via `var.avd_agent_dsc_modules_url` (pin a versioned
`Configuration_x.y.z.zip` there for reproducible builds); the `# UNVERIFIED` marker is replaced with a
dated note. See `modules/session-hosts/{main,variables}.tf`.

**Update (2026-06-20, post-deploy):** the "always-latest" `Configuration.zip` was **reversed** — the
unversioned/native package dropped the `aadJoin` parameter and the DSC extension fails on Entra-join host
pools (`A parameter cannot be found that matches parameter name 'aadJoin'`, RDS-Templates #598). The
default is now pinned to `Configuration_1.0.02627.270.zip` (accepts aadJoin; the AVD agent self-updates
after registration). Both prerequisites were actioned on the subscription during the first live apply:
EncryptionAtHost registered, and the Azure Virtual Desktop SP granted **Desktop Virtualization Power On
Off Contributor** (required by the scaling plan). All verified by a successful deployment.

### OQ-007 — Scope down the CI principal from Owner? → **Contributor + User Access Administrator**
**Resolution (2026-06-14):** Reduced from **Owner** to **Contributor + User Access Administrator** at
subscription scope (least-privilege). Contributor manages resources; User Access Administrator lets the
application landing zone create role assignments (AVD/storage RBAC), which Contributor cannot. See
DECISIONS.md ADR-0005 and `bootstrap/identity.tf`.

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
