#!/usr/bin/env bash
# Shared library: compute a stable fingerprint of the pending commit content.
# Sourced by require-review.sh (the commit gate) and record-review.sh (the approval stamp) so both
# compute it identically.
#
# The fingerprint is the git TREE hash of "HEAD + every pending change" (tracked mods, deletions, and
# new files), computed via a throwaway index so it never touches the real index or working tree. This
# makes it fully INDEX-INDEPENDENT: `git add` between approval and commit does not change it, but any
# change to file content does. Returns non-zero on failure so callers can fail closed.

# Path to the approval sentinel (relative to repo root; gitignored).
REVIEW_GATE_FILE=".claude/review-gate"

# Echoes the tree hash representing all content that `git add -A && git commit` would record.
compute_fingerprint() {
  local gitdir tmpindex tree
  gitdir="$(git rev-parse --git-dir)" || return 1
  tmpindex="$(mktemp)" || return 1
  # Single cleanup path: remove the throwaway index on every return (incl. early failures).
  trap 'rm -f "$tmpindex"' RETURN
  # Seed the throwaway index from the real one, then stage everything into it (respects .gitignore,
  # so the sentinel file itself is excluded). The real index is untouched (GIT_INDEX_FILE redirect).
  [ -f "$gitdir/index" ] && cp "$gitdir/index" "$tmpindex"
  # 2>/dev/null: suppress benign CRLF/autocrlf notices so the gate output stays clean.
  GIT_INDEX_FILE="$tmpindex" git add -A 2>/dev/null || return 1
  tree="$(GIT_INDEX_FILE="$tmpindex" git write-tree 2>/dev/null)" || return 1
  [ -n "$tree" ] || return 1
  printf '%s' "$tree"
}
