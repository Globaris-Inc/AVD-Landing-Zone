# Role Workflow — How We Build This Landing Zone

This project is built by four collaborating roles, each a Claude Code **subagent** in
[`.claude/agents/`](../.claude/agents/), operating **within** the section-per-session model defined in
[`CLAUDE.md`](../CLAUDE.md). Delegate the section's role-specific work to the matching subagent.

## The roles

| Role | Subagent | Owns | Does **not** do |
|------|----------|------|-----------------|
| Cloud Solutions Architect | [`cloud-solutions-architect`](../.claude/agents/cloud-solutions-architect.md) | `ARCHITECTURE.md`, ADRs, topology, identity/network model, module selection | Write infra code |
| Cloud Engineer | [`cloud-engineer`](../.claude/agents/cloud-engineer.md) | `bootstrap/`, `modules/`, `landing-zones/`, `envs/`, local validation | CI/CD, topology decisions |
| DevSecOps Engineer | [`devsecops-engineer`](../.claude/agents/devsecops-engineer.md) | `.github/workflows/`, OIDC, state backend, `policies/`, security posture | Author infra modules |
| Code Reviewer | [`code-reviewer`](../.claude/agents/code-reviewer.md) | Review & merge gate | Implement changes |

## The hand-off loop (within a section)

```
  ┌───────────┐   design + ADR   ┌──────────────┐   modules    ┌──────────────┐
  │ ARCHITECT │ ───────────────▶ │ CLOUD ENGINEER│ ──────────▶ │  DEVSECOPS   │
  └───────────┘                  └──────────────┘              └──────────────┘
        ▲                                                            │ pipeline + harden
        │           changes requested                               ▼
        │                                                     ┌──────────────┐
        └─────────────────────────────────────────────────── │ CODE REVIEWER │
                         approve → merge → next section         └──────────────┘
```

1. **Architect** — decides the section's topology / identity / network model, selects AVM modules,
   records ADRs in `DECISIONS.md`, updates `ARCHITECTURE.md`.
2. **Cloud Engineer** — implements the Terraform from pinned AVM modules, wires inputs/outputs, fills
   `envs/*.tfvars` placeholders, runs `terraform fmt` + `validate`.
3. **DevSecOps** — ensures the pipeline plans/applies the change via OIDC + GitHub Environments, hardens
   security (private endpoints, Key Vault, RBAC, NSGs), runs a security review.
4. **Code Reviewer** — reviews for correctness, AVM/version-pinning, security, naming/tagging. Verdict:
   approve (merge) or changes requested.

## Per-section review gate (required)

After a section is fully written and `terraform fmt -recursive` / `terraform validate` pass, the
**`code-reviewer` subagent reviews that section's diff before it is committed**. Blocker findings are
fixed first; the section is committed only once review is clean.

## Definition of done (per section)
- [ ] Design captured (ADR / `ARCHITECTURE.md`) where a real decision was made
- [ ] Implemented in Terraform, AVM versions pinned, `for_each` not `count`, `common_tags` applied
- [ ] `terraform fmt -recursive` + `terraform validate` pass (or the gap is explicitly reported)
- [ ] Pipeline plans the change; deploy path is OIDC + environment-gated
- [ ] No secrets / real subscription IDs in the repo
- [ ] Code Reviewer approved; naming + tags compliant
- [ ] `WORKLOG.md` updated; suggested commit message provided (commit only when the user asks)

## Where we are
1. **Governance & repo structure** ✅ established.
2. **Build (section loop):** work each `PROMPT.md` section in order; tracker lives in `WORKLOG.md`.
3. **Deploy:** run `bootstrap/` once, fill placeholders, let CI plan/apply to `dev`, then promote.
