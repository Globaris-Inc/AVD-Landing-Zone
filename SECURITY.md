# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report privately via GitHub's **[Private Vulnerability Reporting](https://github.com/teeeke/AVD-Landing-Zone/security/advisories/new)**
(repo → **Security** → **Report a vulnerability**). If that is unavailable, contact the maintainers through a
GitHub Security Advisory rather than a public channel.

Please include: affected file(s)/module(s), a description of the issue and its impact, and reproduction steps
or a proof of concept if possible. We aim to acknowledge reports within **5 business days** and to provide a
remediation timeline after triage.

## Scope

This repository is a **reference / proof-of-concept** Azure Virtual Desktop landing zone (Terraform + Azure
Verified Modules). Relevant security concerns include, for example:

- Insecure defaults in the Terraform modules or composition (public exposure, weak network/identity posture).
- CI/CD workflow weaknesses (privilege escalation, secret exposure, unsafe use of `pull_request_target`).
- Any **committed secret, key, token, or real subscription/tenant/identity value** (see below).

Out of scope: vulnerabilities in upstream providers or Azure Verified Modules themselves — report those to
their respective projects (e.g. the [Azure/terraform-provider-azurerm](https://github.com/hashicorp/terraform-provider-azurerm)
or [Azure Verified Modules](https://github.com/Azure/terraform-azure-modules) repos).

## Secrets & sensitive data

This project ships **no secrets**. All authentication is designed around **OIDC federation** (no stored
client secrets), runtime secrets come from **Key Vault**, and all environment-specific values are
**placeholders** (`<ANGLE_BRACKETS>` / `*.tfvars` templates). State files, `*.secret.tfvars`, and `.env`
files are git-ignored and must never be committed.

If you believe a secret or real subscription/tenant/client ID has been committed (including in history),
treat it as a vulnerability and report it privately — do **not** file a public issue.

## Supported versions

This is an actively-developed reference project; only the latest `main` is supported. There are no
long-term-support branches.
