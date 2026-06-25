# Templates — what to copy + parameterize

The reusable code lives in the **proven repo artifacts** (they're already generic or nearly so). Rather than
duplicate large files, copy these into the new LZ repo and apply the parameterization checklist. They
deploy a real, gated, secret-less pipeline + state backend out of the box.

| Copy | From | Generality |
|------|------|------------|
| State backend | `bootstrap/` | High — generic CMK/GZRS/Entra-only state backend + OIDC. Deterministic naming. |
| Backend/var config | `envs/*.backend.hcl`, `envs/*.tfvars` | High — placeholders + the IDs-via-env pattern |
| Provider/version pins | `*/providers.tf`, `.terraform-version` | High — keep CI pin == this file |
| CI workflows | `.github/workflows/{plan-on-pr,manual-deploy,cleanup-demo,bootstrap}.yml` | High — env/action inputs, OIDC, gating, firewall handling |
| Review gate | `scripts/preflight.sh`, `.githooks/pre-commit`, `.claude/hooks/*`, `.claude/agents/*` | High — generic |
| Composition root | `landing-zones/<workload>/` | Pattern — replace the module wiring with your LZ's modules |
| Modules | `modules/*` | **Example only** — these are AVD-specific; replace with your LZ's modules |
| Governance | `CLAUDE.md`, `PROMPT.md`, `WORKLOG.md`, `DECISIONS.md`, `OPEN-QUESTIONS.md`, `ARCHITECTURE.md` | High — re-section `PROMPT.md` for the new LZ; seed `OPEN-QUESTIONS.md` from [the decision framework](OPEN-QUESTIONS-template.md) |

## Parameterization checklist (what to change for a new LZ)

1. **Workload token & names.** Replace the `avd` token and the design-area module names. Update
   `local.name_prefix` / naming-and-tagging to your CAF convention. Decide region + short name.
2. **State backend stays generic** — only the **deterministic suffix input** (subscription ID) changes by
   environment automatically. Recompute the SA name (`substr(sha1(lower(sub_id)),0,8)`) into `*.backend.hcl`
   (the `bootstrap.yml` drift guard enforces this match).
3. **Workflows are largely turnkey.** They take `environment`/`action` inputs and reach the backend by
   name. Confirm the federated-credential **subjects** match the new repo (`repo:<org>/<repo>:…`) and the
   three repo **Variables** (`AZURE_CLIENT_ID/TENANT_ID/SUBSCRIPTION_ID`) are set as *Variables*, not Secrets.
4. **Modules are the real work.** Swap the AVD `modules/*` for the new LZ's modules (for a **security** LZ:
   Log Analytics + solutions, Microsoft Sentinel, Defender plans/onboarding, policy assignments + RBAC,
   diagnostic-settings-at-scale). Apply the [LESSONS](LESSONS.md) `for_each`/static-key discipline.
5. **Re-section `PROMPT.md`** for the new LZ's design areas; seed `OPEN-QUESTIONS.md` from the
   [decision framework](OPEN-QUESTIONS-template.md) and resolve each as an ADR before building.
6. **Re-derive the subscription prerequisites** ([LESSONS](LESSONS.md) §B) for the services you deploy —
   these are the ones the kit can't generalize.

## Order of operations (new LZ)

```
answer the decision framework (→ ADRs)
  → bootstrap (workflow_dispatch, once: deterministic-named CMK state backend + OIDC)
  → wire GitHub: 3 repo Variables, federated creds for this repo, production Environment + reviewer
  → build section-by-section under the 3-role loop + review gate
  → manual-deploy: plan (PR) → apply (gated) ; cleanup-demo to reset
```
