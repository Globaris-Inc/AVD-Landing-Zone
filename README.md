# Azure Virtual Desktop — Landing Zone (IaC)

Terraform Infrastructure-as-Code for an **Azure Virtual Desktop (AVD) application landing zone**,
following the Microsoft reference architecture:
[AVD Landing Zone Design Guide](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/azure-virtual-desktop/design-guide)
and the [`Azure/avdaccelerator`](https://github.com/Azure/avdaccelerator) baseline.

The landing zone is composed from **[Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/)**
for `azurerm`. CI/CD runs on **GitHub Actions** using **OIDC** federated auth (no stored cloud secrets).

> This is an **application** landing zone. It assumes a CAF **platform** landing zone (connectivity,
> identity, management) already exists — see [Prerequisites](#prerequisites). Stack: **Terraform + AVM only.**

---

## How this project is run

Work follows a strict, section-based contract — read these in order before contributing:

1. **[CLAUDE.md](CLAUDE.md)** — operating rules (one section per session, verify-before-write, pin versions).
2. **[PROMPT.md](PROMPT.md)** — the requirements as 13 numbered sections.
3. **[WORKLOG.md](WORKLOG.md)** — source of truth for what's been done (newest first).
4. **[DECISIONS.md](DECISIONS.md)** / **[OPEN-QUESTIONS.md](OPEN-QUESTIONS.md)** — ADRs and unresolved items.

Four role subagents in `.claude/agents/` (Architect → Cloud Engineer → DevSecOps → Code Reviewer)
operate within that model — see [docs/workflow.md](docs/workflow.md).

## Repository layout

```
ARCHITECTURE.md          Design-area A–I mapping + diagrams
CLAUDE.md PROMPT.md WORKLOG.md DECISIONS.md OPEN-QUESTIONS.md   Governance
.github/workflows/       CI/CD — plan-on-pr, apply-on-merge (OIDC)   [Section 12]
.claude/agents/          The four role subagents
bootstrap/               OIDC federation + Terraform state backend    [Section 2]
modules/                 Reusable AVD modules (one concern each)      [Sections 4–11]
  networking/ identity-join/ fslogix-storage/ security/
  management-plane/ session-hosts/ monitoring/ shared-services/
landing-zones/avd-workload/   Composition root that calls the modules
envs/                    Per-env tfvars + backend config (placeholders)
policies/                Optional guardrails (deny public PaaS, required tags)
docs/                    Naming/tagging + role workflow
```

## Prerequisites

1. A deployed **CAF platform landing zone** (connectivity / identity / management). Not created here.
2. An identity service for session-host domain join (Entra ID join, Entra DS, or AD DS) — see OQ-006.
3. Tooling: **Terraform ≥ 1.9**, `azurerm` ≥ 4.0, `azuread` ≥ 3.0, Azure CLI.
4. Subscriptions for the AVD **workload** and **shared services** application landing zones.

## Quick start

> Replace every `<PLACEHOLDER>` in `envs/*.tfvars` before deploying. Run the one-time `bootstrap/`
> first (creates OIDC federation + the Terraform state backend).

```bash
cd landing-zones/avd-workload
terraform init -backend-config=../../envs/dev.backend.hcl
terraform plan  -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```

In practice, **let CI/CD drive deployments** — PRs run `plan`, merges to `main` run an
environment-gated `apply`. See [.github/workflows](.github/workflows).

## Conventions

- **Naming & tags:** [docs/naming-and-tagging.md](docs/naming-and-tagging.md) (CAF naming + minimum tags).
- **Module versions:** every AVM module is **version-pinned**; bumps go through a PR.
- **Secrets:** none in the repo. CI uses OIDC; runtime secrets live in Key Vault.

## Status

Governance is established; building proceeds section-by-section per `PROMPT.md`. Current progress is in
[WORKLOG.md](WORKLOG.md).
