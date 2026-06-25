# Process — how to run a landing-zone build

The ways of working that kept this build coherent across many sessions and a real deployment. Generalized;
adopt verbatim for the next LZ.

---

## 1. Operating contract

- **One section per session.** Divide the requirements into numbered sections (`PROMPT.md`). Work exactly
  one per session; stop and update the work log rather than rolling into the next.
- **Work log is the source of truth.** A running `WORKLOG.md` (not the context window) carries state
  between sessions. Read it first; append after every meaningful change.
- **Verify before you write.** Confirm every AVM module + version on the registry and every `azurerm`
  argument against current provider docs *before* using it. If you can't verify, mark `# UNVERIFIED:` and
  log it — don't guess.
- **Pin every version** (modules and providers) — exact `x.y.z` for modules, `~>` for provider minors.
- **No speculative building.** Don't create resources the current section doesn't need; note out-of-scope
  ideas in `OPEN-QUESTIONS.md` and stop.
- **Stop and ask on ambiguity** — region, SKU, identity model, naming variant, RBAC scope: surface it,
  don't pick silently.
- **Suggest, don't commit.** Commit only when the owner asks. No AI co-author/attribution trailers. No
  secrets or real subscription/tenant IDs in the repo.

Required root files: `CLAUDE.md` (operating rules), `PROMPT.md` (sectioned requirements), `WORKLOG.md`
(source of truth), `DECISIONS.md` (ADRs), `OPEN-QUESTIONS.md` (decisions needing input), `ARCHITECTURE.md`.

## 2. The 3-role hand-off

For each change: **Architect → (Cloud Engineer _or_ DevSecOps, by domain) → Code Reviewer.** If a change
spans both implementer lanes, engage both in sequence.

| Role | Owns | When |
|------|------|------|
| **Cloud Solutions Architect** | topology, identity/network model, module selection, ADRs | first, when the approach is ambiguous or has trade-offs |
| **Cloud Engineer** | `modules/`, composition root, `bootstrap/` Terraform, `envs/*.tfvars`, local validate | implement Terraform logic |
| **DevSecOps Engineer** | `.github/workflows/`, OIDC, state-backend specifics, `envs/*.backend.hcl`, `policies/`, posture | implement pipeline/security |
| **Code Reviewer** | correctness, AVM/version pinning, security, naming/tagging, `preflight.sh` | the merge gate, before every commit |

Route by **what's being touched**, not by habit — a module change is Cloud Engineer; a workflow/policy
change is DevSecOps.

## 3. The enforced review gate

Don't rely on memory or prose for "we reviewed it" — **enforce it with hooks.**

- **`.githooks/pre-commit`** (enable: `git config core.hooksPath .githooks`) — hard-fails a commit on
  `terraform fmt`/`validate` errors and best-effort `actionlint` on workflow changes.
- **A `PreToolUse` hook** blocks `git commit` unless the exact working-tree content has a recorded
  code-review approval stamp (a tree-hash; any later edit invalidates it). A conscious override exists for
  trivial no-code commits.
- **`scripts/preflight.sh` — "validate the way CI runs."** The reviewer runs it for any Terraform/workflow
  change: checks the **CI Terraform pin == local pin**, runs an isolated `init -backend=false` + `validate`,
  a **module `required_version` floor check** (fails if the pin is below any module's floor), and
  `actionlint`. This is what catches the class of bug a static read can't (see [LESSONS](LESSONS.md) A7, D15).

> The gate's value is proven: it caught real blockers (storage diagnostics collecting nothing, a
> script-injection vector, a fail-open in the gate's own logic) and would have caught the Terraform
> version-floor bug. Its limits are also real — see [LESSONS](LESSONS.md): only a live `apply` catches the
> runtime/prereq/quota class.
