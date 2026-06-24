# bootstrap/ — Chicken-and-Egg Layer

The **one-time, manual** bootstrap for the AVD landing zone. It creates:

- The **remote Terraform state backend** — Resource Group + CMK Key Vault + Storage Account, in the
  AVD workload subscription.
- The **OIDC service principal** for GitHub Actions — no client secrets, federated credentials only.

**This layer uses local Terraform state** (it builds the backend the other roots use, so it can't
depend on it). `terraform.tfstate` here is gitignored and must never be committed. All other root
modules (`landing-zones/`, etc.) use the remote backend created here.

---

## Prerequisites

| Requirement | How |
|---|---|
| Azure CLI ≥ 2.x | `az --version` |
| Terraform ≥ 1.10 | `terraform --version` |
| **Owner or User Access Administrator + Contributor** on the AVD subscription(s) | to run bootstrap, which itself grants the CI principal Contributor + User Access Administrator (ADR-0005) |
| **App Administrator / Privileged Role Admin** on Entra ID | to create the app registration |

---

## One-time procedure

### 1. Authenticate
```bash
az login
az account set --subscription "<AVD_WORKLOAD_SUB_ID>"
az account show --query "{sub:id, tenant:tenantId}" -o table
```

### 2. Configure variables
```bash
cp terraform.tfvars.example terraform.tfvars   # then edit — tenant_id, subscription_id, github_org/repo, ip_allow_list
curl -s https://api.ipify.org                  # your public IP for ip_allow_list
curl -s https://api.github.com/meta | jq '.actions[]'   # GitHub Actions runner ranges
```

### 3. Init & apply
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan        # ~5–8 min (Key Vault, RBAC propagation sleep, Storage CMK)
```

### 4. Capture outputs
```bash
terraform output -json
```

| Output | Use it in |
|---|---|
| `resource_group_name` | `envs/<env>.backend.hcl` → `resource_group_name` |
| `storage_account_name` | `envs/<env>.backend.hcl` → `storage_account_name` |
| `storage_container_name` | `envs/<env>.backend.hcl` → `container_name` (`tfstate`) |
| `oidc_client_id` | GitHub repo variable `AZURE_CLIENT_ID` |
| `oidc_tenant_id` | GitHub repo variable `AZURE_TENANT_ID` |
| `subscription_id` | GitHub repo variable `AZURE_SUBSCRIPTION_ID` |

### 5. Wire GitHub
- **Settings → Secrets and variables → Actions → Variables** (not secrets — OIDC needs none):
  `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
- **Settings → Environments → `production`** — add a required reviewer. The `manual-deploy` workflow
  runs prod apply/destroy under this environment (required-reviewer gate); the matching federated
  credential (`github-env-production`) is already created here.

---

## What is created & why

- **Resource Group `rg-tfstate-avd-001`** — hosts the backend in the AVD workload subscription.
- **Key Vault `kv-tfstate-<suffix>`** — dedicated CMK store; RBAC-authorised, soft-delete + purge
  protection (cannot be accidentally destroyed).
- **Storage Account `sttfstate<suffix>`** — GZRS, **CMK** encryption, blob **versioning**, **shared
  keys disabled** (Entra-ID/RBAC only), `tfstate` container (no WORM — versioning provides state recovery).

> **`<suffix>` is deterministic** (ADR-0008): `substr(sha1(lower(subscription_id)), 0, 8)`. The same
> subscription always yields the same SA/KV names, so re-bootstrap reproduces the names and
> `envs/*.backend.hcl` stays valid. (Previously a `random_string`, whose value lived only in local state.)
- **OIDC SP `sp-avd-lz-cicd`** — no secret; federated creds for the `main` ref, `pull_request`, and the
  `production` environment; **Contributor + User Access Administrator on the AVD subscription(s)** (ADR-0005,
  least-privilege replacement for Owner), plus Storage Blob Data Contributor on the state account.

---

## Deviations

| Deviation | Reason | Remediation |
|---|---|---|
| Storage allows public access (IP allow-list) | the AVD spoke VNet doesn't exist yet | PROMPT.md §7 adds a Private Endpoint; keep `default_action = "Deny"`, drop the IP rules |
| Immutability policy `locked = false` | a locked policy blocks state overwrites | flip to `true` only on a decommissioned/archived container |
| OIDC SP = Contributor + User Access Administrator (not Owner) | app LZ must create role assignments, which Contributor alone cannot | resolved (ADR-0005, OQ-007); add a narrow role assignment if an Owner-only action is ever needed |

---

## Recovery / re-bootstrap

Bootstrap uses **ephemeral state** (ADR-0008): its `.tfstate` is **not** persisted and is never needed
for teardown (`az group delete` via `cleanup-demo.yml`) or deploys (`manual-deploy.yml` reaches the SA by
name). Because the SA/KV names are **deterministic** (`substr(sha1(lower(subscription_id)), 0, 8)`), a
re-bootstrap reproduces the same backend without importing anything.

**Re-bootstrap is a clean re-apply** (local/ephemeral state, `create_oidc_identity = false`) — run it
from CI via `bootstrap.yml` (`workflow_dispatch`, OIDC, `production`-gated) or locally. Notes:

- The **Resource Group / Storage Account** are re-created idempotently; if they already exist the apply
  reconciles them (re-running against a live backend is a no-op plan).
- The **Key Vault is recovered, not re-created.** Its name stays globally reserved while soft-deleted and
  purge protection blocks purge for the full retention window (90 days, not even by Microsoft), so a
  re-bootstrap hits the soft-deleted `kv-tfstate-<suffix>`. `recover_soft_deleted_key_vaults = true`
  (in `providers.tf`) makes the provider **recover** it. Do **not** purge the vault — recovery is the
  intended path and keeps the CMK key intact.
- **Role assignments** are idempotent (same principals, same scopes); re-apply reconciles them.
