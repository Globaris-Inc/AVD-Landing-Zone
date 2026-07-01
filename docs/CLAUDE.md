# CLAUDE.md — Project Instructions for Claude Code

> **Read this file at the start of every session before doing anything else.**
> Then read `WORKLOG.md` to see what's been done, and `OPEN-QUESTIONS.md` for unresolved blockers.
> Read `PROMPT.md` for the full project goal and the section you're working on.

---

## Project: Azure Virtual Desktop — Application Landing Zone (Terraform + AVM)

Infrastructure as Code for an **AVD application landing zone** following the Microsoft AVD Landing Zone
design guide and the `Azure/avdaccelerator` baseline, composed from **Azure Verified Modules (AVM)**.
Full requirements live in `PROMPT.md`. This is an **application** landing zone — the CAF **platform**
landing zone (connectivity / identity / management subscriptions and the management-group hierarchy)
is a **prerequisite**, never built here.

**Stack:** Terraform + AVM only. (Bicep was dropped — see `DECISIONS.md` ADR-0001.)

---

## ⚠️ Hard Operating Rules (Non-Negotiable)

1. **One section per session.** Work is divided into numbered sections in `PROMPT.md`. Work on
   **exactly one section per session**, named by the user at session start. Do not start the next
   section even if tokens remain — stop and update `WORKLOG.md`.

2. **Work log is the source of truth.** Read `WORKLOG.md` before doing anything; update it after every
   meaningful action. The work log — not the context window — carries state between sessions.

3. **No speculative building.** Do not create files, modules, or resources not required by the current
   section. If something seems needed but is out of scope, note it in `WORKLOG.md` / `OPEN-QUESTIONS.md`
   and stop.

4. **Verify before you write.** Before any AVM module call, `azurerm` resource, or Azure config:
   - Confirm the AVM module + version on the Terraform Registry (`registry.terraform.io/modules/Azure/`).
   - Confirm current `azurerm` provider syntax for the resource.
   - If you can't verify, mark it `# UNVERIFIED:` in the file and note it in the work log — don't guess.
   - **Pin every module and provider to a specific version.**

5. **No hallucinated module names or arguments.** AVM modules follow `Azure/avm-ptn-*` or
   `Azure/avm-res-*`. If unsure a module/argument exists, don't write it — use a native `azurerm`
   resource with a `# DEVIATION: <reason>` comment instead. Note: the AVD pattern modules
   (`avm/ptn/avd-lza/*`) are **proposed/unversioned** — prefer published `avm-res-*` resource modules.

6. **Stop and ask when ambiguous.** If a section has a decision point not covered in `PROMPT.md`
   (region, SKU, identity model, naming variant), stop and ask — do not pick for the user and proceed.

7. **No assumptions about prior work.** Even if `WORKLOG.md` says a section is complete, verify the
   files exist before extending them; the log can drift if a session was interrupted.

8. **Hard constraints (always):** Platform landing zone & management groups are out of scope. **No
   secrets in the repo** — CI auth is **OIDC**, runtime secrets come from **Key Vault**. No real
   subscription/tenant IDs committed; use `*.tfvars` placeholders (`<ANGLE_BRACKETS>`) or Key Vault.

---

## 👥 Roles & Subagents

This project keeps four collaborating roles as subagents in `.claude/agents/`. They operate **within**
the section-per-session model — delegate the section's role-specific work to the matching subagent.

| Role | Subagent | Owns |
|------|----------|------|
| Cloud Solutions Architect | `cloud-solutions-architect` | `ARCHITECTURE.md`, ADRs, topology, identity/network model, module selection |
| Cloud Engineer | `cloud-engineer` | `bootstrap/`, `platform/`, `landing-zones/`, `modules/`, `envs/`, local validation |
| DevSecOps Engineer | `devsecops-engineer` | `.github/workflows/`, OIDC, state backend, security posture |
| Code Reviewer | `code-reviewer` | review & merge gate |

Hand-off order within a section: **Architect → Cloud Engineer → DevSecOps → Code Reviewer.**
Detail in [docs/workflow.md](docs/workflow.md).

---

## 🗂️ Required Files in Repo Root

| File | Purpose | Updated By |
|------|---------|-----------|
| `CLAUDE.md` | Operating rules (this file) | User only |
| `PROMPT.md` | Full requirements (numbered sections) | User only |
| `WORKLOG.md` | Running log of work, decisions, deferrals | Claude every session |
| `DECISIONS.md` | Architectural decision records (ADRs) | Claude when a decision is made |
| `OPEN-QUESTIONS.md` | Unresolved items needing user input | Claude when blocked |
| `ARCHITECTURE.md` | Diagrams + design-area mapping + RTO/RPO | Claude (architect) |

---

## 🔄 Session Workflow

**Start:** (1) Read this file. (2) Read `WORKLOG.md` end-to-end. (3) Read `OPEN-QUESTIONS.md` — surface
anything blocking the requested section. (4) Confirm: *"Today we're working on Section N: [title]. Correct?"*
(5) Read the relevant `PROMPT.md` section in full.

**During:** Work only the named section. State each significant file action in one line before doing it.
Append a one-line `WORKLOG.md` entry after each significant change. Ambiguity → write to
`OPEN-QUESTIONS.md` and ask. Architectural choice → add an ADR to `DECISIONS.md`.

**End:** (1) Write a `WORKLOG.md` session summary: section, files created/modified (paths),
modules/versions pinned, decisions (link ADRs), open questions, what's left, recommended next focus.
(2) Run `terraform fmt -recursive` and `terraform validate` on anything created. (3) Provide a one-line
suggested git commit message — **do not commit unless the user asks.**

---

## 🚫 Anti-Hallucination Checklist (before writing any Terraform)

- [ ] AVM module confirmed on the Terraform Registry?
- [ ] Module pinned to a specific version (not `>=` / `latest`)?
- [ ] `azurerm` arguments confirmed against current provider docs?
- [ ] Real Azure SKU / region / API version?
- [ ] If unsure on any of the above → marked `# UNVERIFIED:` and noted in `WORKLOG.md`?

If any answer is "no" — stop and verify, or stop and ask.

---

## 🧱 File Creation Rules (Terraform)

- 2-space indentation; every `.tf` has a header comment (purpose, PROMPT.md section #, last-updated date).
- Every variable has `description` + `type`; every output has `description`.
- Every resource is tagged from `local.common_tags`.
- **`for_each` with maps, not `count`.**
- Module sources pinned: `source = "Azure/avm-res-...|avm-ptn-.../azurerm"` + `version = "x.y.z"`.
- Provider blocks pinned (`~>` for minor flex), never unpinned.
- Comment any deviation from AVM defaults: `# DEVIATION: <reason>`.

---

## 💬 Communication Rules

- Be concise in chat; the work log holds the detail. Don't re-explain the project to the user.
- If about to do something the user might not want, ask first (one sentence).
- End every session with: "Session log updated. Next session: Section N."
