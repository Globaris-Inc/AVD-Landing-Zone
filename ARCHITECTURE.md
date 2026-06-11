# AVD Landing Zone — Architecture

Maps the [Microsoft AVD Landing Zone design areas](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/azure-virtual-desktop/design-guide)
to the Terraform modules this repository deploys. Owned by the `cloud-solutions-architect` role; kept
current as decisions are made (see [DECISIONS.md](DECISIONS.md)). Stack: **Terraform + AVM only**.

## Scope

An **application** landing zone for AVD, assuming an existing CAF **platform** landing zone providing:

- **Connectivity** — hub VNet, Azure Firewall, ExpressRoute/VPN, shared private DNS zones.
- **Identity** — domain services for session-host join (Entra ID join / Entra DS / AD DS).
- **Management** — central monitoring/governance (the AVD workload also runs its own monitoring).

```
                       Platform landing zone (PREREQUISITE — not built here)
   ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
   │  Connectivity  │   │    Identity    │   │   Management   │
   │ hub vnet / fw  │   │  Entra DS/ADDS │   │  central LA/gov│
   └───────┬────────┘   └───────┬────────┘   └────────────────┘
           │ peering            │ domain join
   ════════╪════════════════════╪══════════════════════════════  this repo ↓
   ┌───────┴────────────────────┴───────────────┐   ┌─────────────────────────┐
   │     AVD workload subscription / RG          │   │  AVD shared services    │
   │  • spoke VNet, NSG, ASG, route table        │   │  • Compute Gallery      │
   │  • host pool, app groups, workspace, scaling│   │  • Automation account    │
   │  • session-host VMs (+ AVD extensions)      │   │  • Log Analytics + DCR  │
   │  • FSLogix storage (Azure Files)            │   │    (shared monitoring)  │
   │  • Key Vault + private endpoints + priv DNS │   │                         │
   └─────────────────────────────────────────────┘   └─────────────────────────┘
```

The Terraform composition root is `landing-zones/avd-workload/`, which calls the reusable `modules/*`.

## Design-area mapping (A–I)

| # | Design area | How this repo addresses it | Module |
|---|-------------|----------------------------|--------|
| A | Billing & tenant | Out of scope (platform). | — |
| B | Identity & access | Session-host domain join + RBAC; managed identities; OIDC for CI. | `identity-join`, `session-hosts` |
| C | Resource organization | Workload + shared-services RGs; CAF naming/tags via `locals`. | `landing-zones/avd-workload`, [naming-and-tagging](docs/naming-and-tagging.md) |
| D | Management & monitoring | Log Analytics + data collection rule; diagnostic settings. | `monitoring` |
| E | Network topology & connectivity | Optional spoke VNet (NSG/ASG/route table), peered to platform hub; private DNS. | `networking` |
| F | Security | Key Vault, private endpoints, deny-public storage, NSG/ASG, least-privilege RBAC. | `security`, `fslogix-storage` |
| G | BCDR | Host-pool/VM resilience, Azure Files redundancy, recovery posture. | `session-hosts`, `fslogix-storage` (ADR planned) |
| H | Management baseline | Automation account; scaling plan for cost/perf. | `shared-services`, `management-plane` |
| I | Platform automation & DevOps | Terraform + AVM; GitHub Actions CI/CD (OIDC). | repo-wide, `.github/workflows/` |

## Components → AVM Terraform modules

> Module registry names below; **versions are pinned when each module is built** (per CLAUDE.md
> verify-before-write), confirmed against `registry.terraform.io/modules/Azure/`.

| Module (`modules/…`) | AVM Terraform module(s) (`Azure/…/azurerm`) |
|----------------------|---------------------------------------------|
| `management-plane` | `avm-res-desktopvirtualization-{workspace,hostpool,applicationgroup,scalingplan}` |
| `session-hosts` | `avm-res-compute-virtualmachine` (+ AVD agent/DSC extensions) |
| `fslogix-storage` | `avm-res-storage-storageaccount` (Azure Files, identity-based auth) |
| `security` | `avm-res-keyvault-vault`, `avm-res-network-privateendpoint`, `avm-res-network-privatednszone` |
| `networking` | `avm-res-network-{virtualnetwork,networksecuritygroup,applicationsecuritygroup,routetable}` |
| `monitoring` | `avm-res-operationalinsights-workspace`, `avm-res-insights-datacollectionrule` |
| `shared-services` | `avm-res-compute-gallery`, `avm-res-automation-automationaccount` |
| `identity-join` | native `azurerm` join config (no single AVM module) — `# DEVIATION` documented at build |

## Open decisions (to be recorded as ADRs)
- **Identity model** for session hosts (OQ-006): Entra ID join vs Entra DS vs AD DS.
- **Networking:** new spoke here vs consume an existing spoke from the platform team.
- **BCDR targets:** host-pool region strategy, Azure Files redundancy/backup, RPO/RTO.
- **Host pool type:** pooled vs personal; load-balancing; max session limit.

## Design principles (from the reference)
Subscription democratization · policy-driven governance · application-focused service model ·
single control & management plane.
