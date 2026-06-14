# Naming & Tagging Conventions

Based on the Cloud Adoption Framework:
[resource naming](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming),
[resource abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations),
and [minimum suggested tags](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags).

## Naming pattern

```
<resource-abbreviation>-<workload>-<environment>-<region-short>[-<instance>]
```

- **workload** — short app/workload token, e.g. `avd`.
- **environment** — `dev` | `test` | `prod`.
- **region-short** — e.g. `eus` (East US), `weu` (West Europe).
- **instance** — zero-padded ordinal where multiples exist, e.g. `01`.

Implemented via Terraform `locals` so all resources derive names consistently. Globally-unique,
no-dash names (storage accounts, Key Vault) drop separators and may append a short hash — e.g.
`stavddev<hash>`.

### Examples

| Resource | Abbreviation | Example name |
|----------|--------------|--------------|
| Resource group (workload) | `rg` | `rg-avd-prod-eus` |
| Resource group (shared) | `rg` | `rg-avd-shared-prod-eus` |
| Virtual network | `vnet` | `vnet-avd-prod-eus` |
| Network security group | `nsg` | `nsg-avd-prod-eus` |
| Application security group | `asg` | `asg-avd-sh-prod-eus` |
| Route table | `rt` | `rt-avd-prod-eus` |
| AVD host pool | `vdpool` | `vdpool-avd-prod-eus` |
| AVD application group | `vdag` | `vdag-avd-prod-eus` |
| AVD workspace | `vdws` | `vdws-avd-prod-eus` |
| AVD scaling plan | `vdscaling` | `vdscaling-avd-prod-eus` |
| Session host VM | `vm` | `vm-avd-prod` (+ instance suffix from the host pool) |
| Storage account (FSLogix) | `st` | `stavdprodeus2<hash>` (region token + short hash, capped to 24) |
| Key Vault | `kv` | `kv-avd-prod-<hash>` (short hash, no region token) |
| Log Analytics workspace | `log` | `log-avd-prod-eus` |
| Data collection rule | `dcr` | `dcr-avd-prod-eus` |
| Compute gallery | `gal` | `gal_avd_prod_eus` (underscores; dashes invalid) |
| Automation account | `aa` | `aa-avd-prod-eus` |
| Private endpoint | `pep` | `pep-st-avd-prod-eus` |

> Validate length/charset limits per resource type (e.g. storage ≤ 24 lowercase alphanumerics,
> Key Vault 3–24 chars). The `cloud-engineer` enforces these in the naming logic.

## Minimum tags

Applied to the resource groups and **passed explicitly to every resource** via a `tags` input — Azure
does **not** inherit RG tags. (The AVD `desktopvirtualization` modules take tags via prefixed inputs,
e.g. `virtual_desktop_host_pool_tags`, `virtual_desktop_workspace_tags`.)

| Tag | Purpose | Example |
|-----|---------|---------|
| `workload` | Workload/app name | `avd` |
| `environment` | Lifecycle stage | `prod` |
| `owner` | Team or DRI email | `platform-team@contoso.com` |
| `costCenter` | Chargeback code | `CC-1234` |
| `criticality` | Business impact | `medium` |
| `managedBy` | How it's provisioned | `iac-terraform` |
| `dataClassification` | Sensitivity | `confidential` |

Additional recommended tags: `deploymentDate`, `gitRepo`, `gitCommit` (set by CI).

## Rules
- Lowercase by default; respect per-resource charset/length constraints.
- Names and tags are **derived from inputs**, never hardcoded per environment.
- Centralize naming in Terraform `locals`; surface anything environment-specific as a variable.
