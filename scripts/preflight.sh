#!/usr/bin/env bash
# preflight.sh — "validate the way CI runs". Catches the class of issues a static read of the repo
# cannot see, because they live outside it: transitive module version floors, a CI-vs-local Terraform
# version divergence, and workflow YAML errors. Run as part of the review gate before committing IaC or
# workflow changes (the code-reviewer is instructed to run it — see .claude/agents/code-reviewer.md).
#
# Why this exists: a CI pin of terraform 1.9.8 passed every local check (local ran 1.15.6, which satisfies
# the AVM modules' hidden ">= 1.10" floor) and a static review (the floor is inside gitignored module
# code), then failed only on the first real CI run. This script closes that gap.
#
# Usage:  bash scripts/preflight.sh
# Requires: terraform on PATH. actionlint is optional (skipped if absent).

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
fail=0
roots=(bootstrap landing-zones/avd-workload)

# --- 1. Terraform version: local vs the pinned/CI version ---------------------------------------------
pin="$(tr -d '[:space:]' < .terraform-version 2>/dev/null || true)"
have="$(terraform version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
ci="$(grep -rhoE 'terraform_version: *"[0-9.]+"' .github/workflows/ 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u)"
echo "== terraform version =="
echo "  local: ${have:-unknown}   .terraform-version: ${pin:-none}   CI pin(s): ${ci:-none}"
for c in $ci; do
  if [ -n "$pin" ] && [ "$c" != "$pin" ]; then
    echo "  FAIL: CI terraform_version ($c) != .terraform-version ($pin) — keep them in lockstep."; fail=1
  fi
done
[ -n "$pin" ] && [ -n "$have" ] && [ "$pin" != "$have" ] && \
  echo "  WARN: local terraform ($have) differs from the pin ($pin); validate with the pinned version."

# --- 2. Per root: init (no backend), validate, and a module version-floor check -----------------------
# semver "<=" via sort -V: a satisfies ">= b"  iff  min(a,b) == b.
ver_lt() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]; }

# Isolated data dir so we never disturb the real .terraform (backend config, locks). gitignored.
data=".preflight-tfdata"
for root in "${roots[@]}"; do
  echo "== $root: init -backend=false + validate (isolated) =="
  rm -rf "$root/$data"
  if ! TF_DATA_DIR="$data" terraform -chdir="$root" init -backend=false -input=false >/dev/null 2>&1; then
    echo "  FAIL: terraform init failed in $root."; rm -rf "$root/$data"; fail=1; continue
  fi
  if TF_DATA_DIR="$data" terraform -chdir="$root" validate >/dev/null 2>&1; then echo "  validate ok"; else echo "  FAIL: validate"; fail=1; fi

  # Highest ">=" required_version floor across every downloaded module.
  floor="$(grep -rhoE 'required_version[^"]*"[^"]*' "$root/$data/modules" 2>/dev/null \
            | grep -oE '>= *[0-9]+\.[0-9]+(\.[0-9]+)?' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' \
            | sort -V | tail -1 || true)"
  if [ -n "$floor" ] && [ -n "$pin" ]; then
    if ver_lt "$pin" "$floor"; then
      echo "  FAIL: pinned terraform $pin is BELOW a module required_version floor of $floor in $root."; fail=1
    else
      echo "  version floor ok (modules need >= $floor; pin is $pin)"
    fi
  fi
  rm -rf "$root/$data" # non-destructive: leave no residue on the success path
done

# --- 3. Workflow lint ---------------------------------------------------------------------------------
echo "== actionlint =="
if command -v actionlint >/dev/null 2>&1; then
  actionlint && echo "  actionlint ok" || { echo "  FAIL: actionlint"; fail=1; }
else
  echo "  actionlint not installed — skipped (install: https://github.com/rhysd/actionlint)"
fi

echo "------------------------------------------------------------"
if [ "$fail" -eq 0 ]; then echo "PREFLIGHT PASS"; else echo "PREFLIGHT FAIL"; exit 1; fi
