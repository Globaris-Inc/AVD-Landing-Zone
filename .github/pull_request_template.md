<!-- Thanks for contributing! Keep PRs focused on one concern. -->

## What & why

<!-- What does this change do, and why? Link any related issue (e.g. Closes #123). -->

## Checklist

- [ ] `terraform fmt -recursive` is clean and `bash scripts/preflight.sh` passes (validate the way CI runs)
- [ ] AVM modules / providers are **version-pinned** (no `latest`/`>=`); new arguments verified against the pinned version
- [ ] **No secrets or real subscription/tenant/client IDs** — placeholders only; no `tfstate`/`*.secret.tfvars`/`.env` committed
- [ ] `for_each` with maps (not `count`); optional resources gated on static booleans
- [ ] Docs updated where relevant (README / ARCHITECTURE); an ADR added to `DECISIONS.md` if this makes an architectural decision
- [ ] Conventional Commit title (`feat:` / `fix:` / `docs:` / `ci:` / `chore:`)

## Notes for reviewers

<!-- Anything reviewers should focus on, known limitations, `# UNVERIFIED:` markers, follow-ups. -->
