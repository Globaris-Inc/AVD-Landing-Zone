#!/usr/bin/env bash
# Stamp review approval for the CURRENT pending-commit content.
# Run ONLY after the code-reviewer subagent has passed (or its fixes are applied).
# Writes the tree fingerprint to .claude/review-gate, which require-review.sh checks at commit time.

set -euo pipefail
trap 'echo "review-gate: failed to record approval — no stamp written." >&2; exit 1' ERR

cd "$(git rev-parse --show-toplevel)"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_fingerprint.sh
source "$DIR/_fingerprint.sh"

fp="$(compute_fingerprint)"
[ -n "$fp" ] || { echo "review-gate: empty fingerprint — refusing to write stamp." >&2; exit 1; }
printf '%s\n' "$fp" > "$REVIEW_GATE_FILE"

echo "review-gate: approval recorded for the current content (${fp:0:12}…)."
echo "review-gate: 'git add' is fine; any content edit invalidates this and requires re-review."
