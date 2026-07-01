# Public-Collaboration Readiness Standard

A reusable checklist for taking an Infrastructure-as-Code repo **public** for open collaboration. Work it
top-to-bottom before flipping visibility. S1 is a hard gate; S3–S5 are the bulk of the work; S6 is polish.
(Applied first to `AVD-Landing-Zone` — see that repo as the worked example.)

---

## S1 — Security & privacy (the go/no-go gate)

Public means **history is public too** — a secret in an old commit is exposed even if the tip is clean.

- [ ] No secrets/keys/tokens in the tree **or history** — scan with `gitleaks detect --source . -v`
      (`fetch-depth: 0`), not just a grep of the tip.
- [ ] No real subscription / tenant / client / object IDs — pin-axe the history:
      `git log --all -S '<known-id>' --oneline` returns nothing; everything is a placeholder
      (`<ANGLE_BRACKETS>` / `*.tfvars` templates).
- [ ] No PII / private org identifiers (emails, internal domains, employee names) in tree or history.
- [ ] Commit-author identities are acceptable to publish (`git log --all --format='%an <%ae>' | sort -u`).
- [ ] `.gitignore` covers `*.tfstate*`, `**/.terraform/*`, `*.secret.tfvars`, `.env*`, and any local creds.
- [ ] Enable GitHub **secret scanning + push protection** (free on public repos) so a future leak is blocked.

> If anything above fails, **do not flip public**. Rotate the exposed secret, then rewrite history
> (`git filter-repo`) or start a fresh repo — deleting the file in a new commit is **not** enough.

## S2 — Legal

- [ ] A `LICENSE` at the repo root (MIT/Apache-2.0 for reusable IaC; MIT is simplest).
- [ ] Third-party attribution noted (e.g. Azure Verified Modules are MIT — a README line suffices for MIT-on-MIT).

## S3 — Community-health files

- [ ] `README.md` — what it is, quickstart, prerequisites, cost, teardown.
- [ ] `CONTRIBUTING.md` — dev setup, local validate/preflight, the review gate, PR process + DoD, no-secrets rule.
- [ ] `CODE_OF_CONDUCT.md` — Contributor Covenant 2.1, with a private reporting channel.
- [ ] `SECURITY.md` — vulnerability-reporting policy (use **private vulnerability reporting**, not public issues).
- [ ] `.github/CODEOWNERS` — review ownership.
- [ ] `.github/pull_request_template.md` + `.github/ISSUE_TEMPLATE/{bug,feature,config}` — structured intake.

## S4 — Public-safe CI/CD (the part people forget)

Fork PRs get **no secrets and no OIDC** by design — so credentialed workflows can't run on them.

- [ ] A **credential-free** gate (`fmt -check` + per-root `init -backend=false` + `validate` + lint) that runs
      on **every** PR incl. forks — `permissions: contents: read`, no `id-token`, no secrets. This is the green
      check external contributors receive.
- [ ] OIDC **plan/apply** workflows gated to same-repo branches
      (`if: github.event.pull_request.head.repo.full_name == github.repository`) so fork PRs **skip** them
      (neutral), not red-fail. Deploy/destroy stay `workflow_dispatch` (maintainer-only).
- [ ] Secret scanning (`gitleaks`) + IaC scanning (`tflint`/`tfsec`/`checkov`) jobs on PR.
- [ ] `.github/dependabot.yml` for `github-actions` + `terraform`.
- [ ] Least-privilege `permissions:` on every workflow; **never** `pull_request_target` with checkout of
      untrusted head code; pin actions.

## S5 — Repo governance (GitHub settings — UI, not code)

- [ ] Branch protection on `main`: require PR + ≥1 review, required status checks (the credential-free gate),
      dismiss-stale approvals, no force-push, no deletion, require conversation resolution.
- [ ] Secret scanning + push protection **on**; Dependabot alerts + security updates **on**.
- [ ] **Private vulnerability reporting** enabled.
- [ ] Repo description + topics; disable unused features (wiki/projects); protect release tags.

## S6 — Docs & contributor experience

- [ ] README badges (license, CI status, terraform version) + a short **Contributing** section.
- [ ] Curate internal/working docs (build logs, agent instructions) into `docs/` so the front page is clean.
- [ ] Optional: per-module `README` via `terraform-docs`.

---

## Verify

- `gitleaks detect` exits clean over full history.
- GitHub **Insights → Community Standards** shows every item green.
- A test PR **from a fork** gets a green credential-free check; the OIDC workflows show **skipped**.
- A direct push to `main` is rejected by branch protection.
