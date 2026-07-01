# Contributing

Thanks for your interest in contributing! This is a reference **Azure Virtual Desktop landing zone**
(Terraform + Azure Verified Modules, OIDC CI/CD). Contributions of all sizes are welcome — bug fixes,
module improvements, docs, and new design areas.

Please also read the [Code of Conduct](CODE_OF_CONDUCT.md) and the [Security Policy](SECURITY.md).

## Ground rules

- **No secrets, ever.** Authentication is OIDC (no stored client secrets); runtime secrets come from Key
  Vault. All environment values are **placeholders** (`<ANGLE_BRACKETS>` / `*.tfvars` templates). Never
  commit real subscription/tenant/client IDs, `terraform.tfstate`, `*.secret.tfvars`, or `.env` files
  (they're git-ignored — keep it that way).
- **Pin everything.** Every AVM module and provider is version-pinned. Don't use `latest`/`>=`.
- **Verify before you write.** Confirm an AVM module + version exists on the Terraform Registry and that
  `azurerm` arguments match the *pinned* provider before adding them. If you can't verify, mark it
  `# UNVERIFIED:` and say so in the PR. (See the hard-won gotchas in
  [`landing-zone-kit/LESSONS.md`](landing-zone-kit/LESSONS.md).)
- **`for_each` with maps, not `count`.** Gate optional resources on static booleans, not unknown IDs.

## Local development

Prerequisites: **Terraform** (see `.terraform-version`), **Azure CLI ≥ 2.x**, `git`.

```bash
# 1. Fork + clone, then branch off main
git checkout -b fix/short-description

# 2. Format + validate the way CI does (no Azure creds needed)
terraform fmt -recursive
bash scripts/preflight.sh        # version-floor check + isolated init/validate + actionlint
```

The repo has an **enforced review gate** (`.githooks/pre-commit` + a commit hook) — see
[`docs/review-gate.md`](docs/review-gate.md). Local `plan`/`apply` require your own Azure subscription and an
OIDC/service-principal setup (see [`bootstrap/`](bootstrap)); you do **not** need Azure access to contribute
code — the CI **validate** gate is credential-free and runs on every PR (including forks).

## Pull requests

1. Keep PRs focused; one concern per PR.
2. Fill in the PR template checklist (fmt/validate clean, no secrets, docs updated).
3. Ensure the **`validate`** check is green. (Plan/apply workflows only run on maintainer/same-repo branches —
   they're expected to be *skipped* on fork PRs, not failed.)
4. Use **[Conventional Commits](https://www.conventionalcommits.org/)** (`feat:`, `fix:`, `docs:`, `ci:`,
   `chore:`) — the PR title becomes the squash-merge subject.
5. If your change makes an architectural decision (region, identity model, module choice, a deviation),
   add an ADR to [`DECISIONS.md`](DECISIONS.md).

## Project process

This repo was built under a lightweight role/section process documented in
[`landing-zone-kit/`](landing-zone-kit) (the reusable build kit). You don't need to follow it to contribute,
but it explains the conventions, the decision framework, and the live-apply lessons behind the code.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
