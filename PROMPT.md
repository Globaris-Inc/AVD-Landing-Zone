# PROMPT.md — Project Requirements

**Target stack:** Terraform with Azure Verified Modules (AVM) for `azurerm` (+ `azuread` where needed)
**Reference:** [Microsoft AVD Landing Zone design guide](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/azure-virtual-desktop/design-guide) · `Azure/avdaccelerator` baseline
**Context:** An **application** landing zone for Azure Virtual Desktop, deployed on top of an existing
CAF **platform** landing zone (connectivity / identity / management). Portfolio-grade, deployable on a
modest subscription, but architecturally faithful to the AVD LZ baseline.

> This file is **read-only reference** for Claude Code. Scope changes go through the user.

---

## Master Prompt

You are a senior Azure platform engineer. Generate a complete, deployable **Terraform** IaC solution
implementing the **Azure Virtual Desktop application landing zone** from Microsoft's AVD LZ design
guide. Use **Azure Verified Modules** (`Azure/avm-res-*`, and `Azure/avm-ptn-*` where a published
pattern fits) from the Terraform Registry; fall back to native `azurerm` only when no AVM module fits,
documented inline with `# DEVIATION:`. The platform landing zone is a prerequisite and is **not** built
here. Optimize for clarity, modularity, security-by-default (private endpoints, OIDC, Key Vault), and
demonstrable CAF best practices.

---

## 1. Repository Structure

Re-pattern to match the sibling `Azure-Architecture` repo. Remove the dropped Bicep stack.

```
avd-landing-zone/
├── README.md
├── ARCHITECTURE.md           # Mermaid diagrams, design-area A–I mapping, RTO/RPO
├── CLAUDE.md  PROMPT.md  WORKLOG.md  DECISIONS.md  OPEN-QUESTIONS.md
├── .github/workflows/        # plan-on-pr.yml, apply-on-merge.yml
├── .claude/agents/           # the four role subagents (kept)
├── bootstrap/                # OIDC SP/federated creds, TF state backend
├── modules/                  # reusable AVD modules (see §, one concern each)
│   ├── networking/           # spoke VNet, NSG, ASG, route table
│   ├── identity-join/        # domain-join config (Entra ID join / Entra DS / AD DS)
│   ├── fslogix-storage/      # Azure Files, identity-based auth, private endpoint
│   ├── security/             # Key Vault, private endpoints, private DNS
│   ├── management-plane/     # workspace, host pool, app groups, scaling plan
│   ├── session-hosts/        # session-host VMs + AVD agent/DSC, autoscale
│   ├── monitoring/           # Log Analytics, AVD Insights, DCRs, diagnostics
│   └── shared-services/      # Compute Gallery, Automation account
├── landing-zones/
│   └── avd-workload/         # composition root that calls the modules
├── envs/
│   ├── dev.tfvars  prod.tfvars
│   └── dev.backend.hcl  prod.backend.hcl
└── policies/                 # optional guardrails (deny public PaaS, required tags)
```

## 2. Bootstrap — OIDC, State Backend, Providers
- GitHub OIDC: Entra app registration + **federated credentials** (no client secrets).
- Terraform remote state: Azure Storage Account (versioning, blob-lease locking; CMK optional).
- `providers.tf`: pin `terraform >= 1.9`, `azurerm >= 4.0`, `azuread >= 3.0`; subscription via env/OIDC.
- `bootstrap/` is run once; outputs feed `envs/*.backend.hcl` and GitHub secrets/vars.

## 3. Resource Organization, Naming & Tagging
- Workload RG + shared-services RG (per the reference architecture).
- CAF naming (`docs/naming-and-tagging.md`) via a naming convention in `locals`.
- Mandatory tags via `local.common_tags`: `workload`, `environment`, `owner`, `costCenter`,
  `criticality`, `managedBy`, `dataClassification`.

## 4. Networking (spoke)
- Optional new spoke VNet (`var.deploy_networking`) with subnets for session hosts + private endpoints.
- NSG (AVD reverse-connect; no inbound RDP), ASG for session hosts, route table (egress to platform FW).
- Peering to the platform hub VNet (`var.hub_vnet_resource_id`); else consume existing subnets.

## 5. Identity & Domain Join
- `var.identity_mode` toggle: `entra-id-join` | `entra-ds` | `ad-ds`.
- Drives session-host join config and the FSLogix storage `directory_service_options`.
- AD DS path requires domain GUID/SID + join credentials (from Key Vault). **Decision needed — OQ-006.**

## 6. FSLogix Profile Storage
- `avm-res-storage-storageaccount`: `FileStorage` Premium, identity-based auth, `fslogix` share.
- Public access disabled; private endpoint to the file sub-resource + `privatelink.file.*` DNS zone.

## 7. Security — Key Vault, Private Endpoints, Private DNS
- `avm-res-keyvault-vault`: RBAC-authorized, purge protection, public access disabled, private endpoint.
- `privatelink.vaultcore.azure.net` + `privatelink.file.*` private DNS zones linked to the spoke.
- Least-privilege RBAC; managed identities for resources.

## 8. Management Plane
- `avm-res-desktopvirtualization-*`: workspace, host pool (Pooled/Personal via `var.host_pool_type`),
  application group(s), and an autoscale **scaling plan** (Pooled schedule baseline).
- Diagnostic settings to the Log Analytics workspace.

## 9. Session Hosts
- `avm-res-compute-virtualmachine` (loop with `for_each`): VMs + AVD agent/boot-loader (DSC) extension,
  registered to the host pool; domain join per §5; autoscale via the scaling plan.
- Image from Marketplace or the Compute Gallery (§11).

## 10. Monitoring — AVD Insights
- `avm-res-operationalinsights-workspace` + data collection rule(s) for AVD perf/event counters.
- Diagnostic settings on host pool, workspace, session hosts, storage, Key Vault.

## 11. Shared Services
- `avm-res-compute-gallery` (image distribution) + `avm-res-automation-automationaccount` (runbooks).
- Optional custom image build pipeline (deferred unless requested).

## 12. CI/CD — GitHub Actions (OIDC)
- `plan-on-pr.yml`: `fmt -check`, `validate`, `tflint`, `plan` (no apply). PR gate.
- `apply-on-merge.yml`: `apply` on merge to `main`, gated by a GitHub Environment with required reviewers.
- OIDC `azure/login`; least-privilege `permissions:` (`id-token: write`, `contents: read`).

## 13. Documentation & Acceptance
- `README.md` (quickstart, prereqs, teardown), `ARCHITECTURE.md` (diagrams, design-area A–I, RTO/RPO),
  per-module `README.md` (terraform-docs).
- **Acceptance:** `terraform validate` clean; `plan` succeeds against a real subscription; all PaaS
  resolves via private endpoint; a user can launch a desktop from the AVD client; FSLogix profile loads.

---

## Constraints
- Terraform `>= 1.9`, `azurerm `>= 4.0`, `azuread >= 3.0`; **pin every module + provider version.**
- No hardcoded subscription/tenant IDs or secrets — tfvars placeholders or Key Vault only.
- Every resource: `common_tags`, diagnostic settings, `lifecycle.prevent_destroy` where appropriate.
- Comment any deviation from AVM defaults: `# DEVIATION: <reason>`. Mark unverified items `# UNVERIFIED:`.
- Platform landing zone & management-group hierarchy are **out of scope**.
