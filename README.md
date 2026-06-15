# Azure Virtual Desktop — Landing Zone (IaC)

Terraform Infrastructure-as-Code for an **Azure Virtual Desktop (AVD) application landing zone**,
following the Microsoft [AVD Landing Zone design guide](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/azure-virtual-desktop/design-guide)
and the [`Azure/avdaccelerator`](https://github.com/Azure/avdaccelerator) baseline. Composed from
**[Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/)** for `azurerm`,
delivered through **GitHub Actions** with **OIDC** (no stored cloud secrets).

> An **application** landing zone — it assumes a CAF **platform** landing zone (connectivity, identity,
> management) already exists. See [Prerequisites](#prerequisites). Stack: **Terraform + AVM only.**

---

## What gets deployed

| Module | Resources | AVM |
|--------|-----------|-----|
| `networking` | Spoke VNet, NSG (reverse-connect), ASG, route table, optional hub peering | network/* |
| `identity-join` | Identity-mode config (Entra ID join baseline) — no DCs deployed | (config) |
| `fslogix-storage` | Premium Azure Files (Entra Kerberos) + file private endpoint | storage-storageaccount |
| `security` | Key Vault (RBAC, private endpoint) + private DNS | keyvault-vault |
| `management-plane` | Host pool, application group, workspace, scaling plan | desktopvirtualization/* |
| `session-hosts` | Session-host VMs + Entra join + AVD agent registration | compute-virtualmachine |
| `monitoring` | Log Analytics + AVD data collection rule + diagnostics | operationalinsights, insights/dcr |
| `shared-services` | Compute Gallery + Automation account | compute-gallery, automation |

Composition root: [`landing-zones/avd-workload/`](landing-zones/avd-workload). Full design-area (A–I)
mapping: [ARCHITECTURE.md](ARCHITECTURE.md).

## Repository layout

```
ARCHITECTURE.md  CLAUDE.md  PROMPT.md  WORKLOG.md  DECISIONS.md  OPEN-QUESTIONS.md   Governance
.github/workflows/    plan-on-pr.yml, apply-on-merge.yml (OIDC, env-gated)
bootstrap/            one-time: OIDC federation + Terraform state backend (CMK)
modules/              the eight AVD modules above
landing-zones/avd-workload/   composition root (calls the modules)
envs/                 dev/prod tfvars + backend.hcl (placeholders)
policies/             optional guardrails
docs/                 naming/tagging, role workflow, acceptance
```

## Prerequisites

1. A deployed **CAF platform landing zone** (connectivity / identity / management). Not created here.
2. **Microsoft Entra ID join** for session hosts is the baseline (ADR-0003). Entra Kerberos enables
   FSLogix on Azure Files. (`entra-ds` / `ad-ds` are toggle options.)
3. Tooling: **Terraform ≥ 1.9**, `azurerm` ≥ 4, Azure CLI (plus `azuread` ≥ 3 for `bootstrap/` only).
   On Windows, set `git config --global core.longpaths true` (AVM modules nest deeply).
4. Subscription(s) for the AVD **workload** (+ optional shared-services).

## Deploy

```bash
# 1) One-time bootstrap (OIDC federation + state backend) — see bootstrap/README.md
cd bootstrap && terraform init && terraform apply -var-file=terraform.tfvars

# 2) Fill the <PLACEHOLDER>s in envs/<env>.backend.hcl and envs/<env>.tfvars from the outputs,
#    and set the GitHub repo variables AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_SUBSCRIPTION_ID.

# 3) Let CI drive it: PRs run plan (dev); merge to main runs apply (prod, behind the
#    'production' GitHub Environment). Or locally:
cd landing-zones/avd-workload
terraform init -backend-config=../../envs/dev.backend.hcl
terraform plan -var-file=../../envs/dev.tfvars
```

## Before the first apply

- Open questions OQ-006/007/008 are all **resolved** (see [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md)). The one
  operational step that remains: register `Microsoft.Compute/EncryptionAtHost` on the subscription, or set
  `session_host_encryption_at_host = false` in `envs/*.tfvars` if it isn't registered.
- Replace every `<PLACEHOLDER>` in `envs/*` and `bootstrap/terraform.tfvars` (never committed).

## How it's built

Built section-by-section under a governance contract ([CLAUDE.md](CLAUDE.md), [PROMPT.md](PROMPT.md)) with
four role subagents — Architect → Cloud Engineer → DevSecOps → Code Reviewer ([docs/workflow.md](docs/workflow.md)).
**Progress is tracked in [WORKLOG.md](WORKLOG.md)** (source of truth); decisions in [DECISIONS.md](DECISIONS.md).
