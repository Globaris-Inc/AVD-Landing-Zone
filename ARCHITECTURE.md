# AVD Landing Zone — Architecture

Maps the [Microsoft AVD Landing Zone design areas](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/azure-virtual-desktop/design-guide)
to the Terraform modules this repo deploys. Owned by the `cloud-solutions-architect` role; decisions in
[DECISIONS.md](DECISIONS.md). Stack: **Terraform + AVM only**.

## Scope

An **application** landing zone for AVD, on top of an existing CAF **platform** landing zone
(connectivity / identity / management). The composition root `landing-zones/avd-workload/` creates a
**workload** RG and a **shared-services** RG (single-subscription model) and calls the `modules/*`.

```
            Platform landing zone (PREREQUISITE — not built here)
   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
   │ Connectivity │  │   Identity   │  │  Management  │
   │ hub / firewall│  │  Entra ID    │  │  central gov │
   └──────┬───────┘  └──────┬───────┘  └──────────────┘
   peering│           join  │
   ═══════╪═════════════════╪══════════════════════════  this repo ↓
   ┌──────┴───────────────────────────────┐  ┌───────────────────────┐
   │  AVD workload RG                      │  │  AVD shared-services RG│
   │  networking · fslogix-storage ·       │  │  monitoring (LAW+DCR) ·│
   │  security(KV) · management-plane ·     │  │  shared-services       │
   │  session-hosts · private DNS zones     │  │  (gallery + automation)│
   └───────────────────────────────────────┘  └───────────────────────┘
```

## Design-area mapping (A–I)

| # | Design area | Addressed by |
|---|-------------|--------------|
| A | Billing & tenant | Out of scope (platform) |
| B | Identity & access | Entra ID join (ADR-0003), `identity-join`, `session-hosts`; managed identities; OIDC CI |
| C | Resource organization | Workload + shared RGs; CAF naming/tags (`docs/naming-and-tagging.md`) |
| D | Management & monitoring | `monitoring` (LAW + DCR + diagnostics on host pool/workspace/KV/storage/session hosts) |
| E | Network topology | `networking` (spoke VNet, NSG/ASG/route table, hub peering) |
| F | Security | `security` (Key Vault), private endpoints + private DNS, RBAC, FSLogix hardening |
| G | BCDR | host-pool/VM resilience, Azure Files redundancy (see RTO/RPO below) |
| H | Management baseline | `shared-services` (Automation), `management-plane` (scaling plan) |
| I | Platform automation & DevOps | Terraform + AVM; GitHub Actions CI/CD (OIDC) |

## Components → AVM modules (pinned)

| Module | AVM (version) |
|--------|---------------|
| networking | network-{virtualnetwork 0.17.1, networksecuritygroup 0.5.1, applicationsecuritygroup 0.1.1, routetable 0.5.0} + native private DNS zones |
| fslogix-storage | storage-storageaccount 0.7.2 |
| security | keyvault-vault 0.10.2 |
| management-plane | desktopvirtualization-{hostpool 0.4.0, applicationgroup 0.2.1, workspace 0.2.2, scalingplan 0.2.1} + native ws↔ag association |
| session-hosts | compute-virtualmachine 0.21.0 (+ AADLoginForWindows, AVD-agent DSC, AzureMonitorAgent extensions) |
| monitoring | operationalinsights-workspace 0.5.1, insights-datacollectionrule 0.1.0 |
| shared-services | compute-gallery 0.2.0, automation-automationaccount 0.2.0 |

## Key design decisions
- **Entra ID join** baseline (ADR-0003) → FSLogix Azure Files uses Entra Kerberos (`AADKERB`).
- **Private-only PaaS** — storage + Key Vault public access disabled, reached via private endpoints; the
  `privatelink.file` / `privatelink.vaultcore` zones are native `azurerm` (DEVIATION: avoids extra deps).
- **`deploy_networking` gating** — the spoke and everything depending on it (FSLogix, KV PE, session
  hosts) are gated via `for_each` so the plan never null-dereferences when networking is off.
- **OIDC CI** (ADR-0002) — no stored secrets; CMK-encrypted remote state.

## RTO / RPO (targets, to validate per environment)
- **Compute (session hosts):** disposable — rebuilt from a Compute Gallery image; low RTO. Pooled hosts
  carry no state.
- **Profiles (FSLogix):** the stateful tier. **Implemented:** Azure Files **ZRS** (var
  `fslogix_account_replication_type`, default `ZRS`). **Not yet wired (future BCDR):** Azure Files
  **backup**, and **FSLogix Cloud Cache** / cross-region replication for multi-region DR — these would
  set/lower the RPO. `prevent_destroy` on the profile store is also a recommended follow-up.
- **State backend:** GZRS + blob versioning + CMK (bootstrap). Resource names are **deterministic** —
  the SA/KV suffix is `substr(sha1(lower(subscription_id)), 0, 8)` (ADR-0008), so re-bootstrap reproduces
  the same names and `envs/*.backend.hcl` stays valid. Bootstrap runs with **ephemeral/local state** (its
  state is discarded; teardown is `az group delete`, deploys reach the SA by name — neither needs it) and
  can be re-run from CI via `bootstrap.yml` (`workflow_dispatch`, OIDC, `production`-Environment gated).

## Open decisions
None outstanding. Recently resolved: OQ-006 identity model (Entra ID join, ADR-0003); OQ-007 CI principal
scoped Owner → Contributor + User Access Administrator (ADR-0005); OQ-008 encryption-at-host toggle +
always-latest AVD-agent DSC artifact. The one operational pre-apply step is registering
`Microsoft.Compute/EncryptionAtHost` (or setting the toggle off). See [OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md).
