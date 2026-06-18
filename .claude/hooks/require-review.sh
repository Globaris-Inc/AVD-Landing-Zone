#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Bash). Runs on every Bash tool call; acts only on git commits.
# Hard-blocks `git commit` unless the current pending-commit content has a matching approval stamp
# recorded by record-review.sh (i.e. the code-reviewer gate passed for THIS exact content).
#
# FAIL CLOSED: PreToolUse blocks the tool ONLY on exit code 2. Once a payload is identified as a commit,
# any internal error must therefore exit 2 (not crash with 127/128, which would let the commit through).
# The ERR trap below enforces that. Non-commit calls exit 0 before the trap can matter.
#
# Detection is a heuristic on the command string. It catches `git commit`, `git -C dir commit`,
# `git -c k=v commit`, and `… && git commit`. It CANNOT see shell aliases (e.g. `gc`) — those bypass it.
#
# Escape hatch: prefix the commit with REVIEW_GATE_OVERRIDE=1 to bypass consciously (logged). Trivial,
# no-code commits only.

set -euo pipefail
trap 'echo "review-gate: internal error — blocking commit (fail closed)." >&2; exit 2' ERR

payload="$(cat || true)"

# Is this a git commit? "git" then "commit" within one command segment (no &&/||/; between them).
# Non-commits (and empty payloads) are let through untouched. False positives fail closed — acceptable.
if ! printf '%s' "$payload" | grep -Eq '\bgit\b[^&|;]*\bcommit\b'; then
  exit 0
fi

# Conscious override.
if printf '%s' "$payload" | grep -q 'REVIEW_GATE_OVERRIDE=1'; then
  echo "review-gate: OVERRIDE used — commit allowed without a matching review stamp." >&2
  exit 0
fi

# From here we KNOW it's a commit: every failure path must block (exit 2). The ERR trap guarantees it.
cd "$(git rev-parse --show-toplevel)"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_fingerprint.sh
source "$DIR/_fingerprint.sh"

current="$(compute_fingerprint)"
approved=""
[ -f "$REVIEW_GATE_FILE" ] && approved="$(tr -d '[:space:]' < "$REVIEW_GATE_FILE")"

if [ -n "$current" ] && [ "$approved" = "$current" ]; then
  exit 0
fi

cat >&2 <<EOF
BLOCKED by review gate: the changes about to be committed have NOT passed the code-reviewer gate
(no matching approval stamp).

Required before committing:
  1. Run the code-reviewer subagent on the working-tree changes.
  2. If it APPROVES (or after applying its fixes), record approval:
         bash .claude/hooks/record-review.sh
     This stamps the CURRENT pending-commit content. Any further edit invalidates it.
  3. Retry the commit (staging with 'git add' does NOT invalidate the stamp).

Trivial no-code commit? Bypass consciously:  REVIEW_GATE_OVERRIDE=1 git commit ...
EOF
exit 2
