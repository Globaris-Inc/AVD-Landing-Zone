# Review gate — enforced pre-commit controls

The reviewer/test gate used to live only as prose in `CLAUDE.md`, so it could be (and was) skipped.
It is now **enforced by hooks** that run automatically — not by anyone remembering.

## The two halves

### 1. Testing gate — git `pre-commit` hook
`.githooks/pre-commit` hard-fails any commit when:
- `terraform fmt -check -recursive` finds unformatted files, or
- `terraform validate` errors on an already-initialized root (`bootstrap`, `landing-zones/avd-workload`).

**Must be enabled once per clone** (git config is local, not committed — a fresh clone has no fmt/validate
gate until this is run):
```bash
git config core.hooksPath .githooks
```

### 2. Review gate — Claude Code `PreToolUse` hook
`.claude/settings.json` registers a `PreToolUse` hook (filtered to `git commit`) that runs
`.claude/hooks/require-review.sh`. It **blocks the commit** (exit 2) unless the current working-tree
state has a matching approval stamp.

Approval is recorded only after the code-reviewer subagent passes:
```bash
bash .claude/hooks/record-review.sh
```
This stamps a fingerprint into `.claude/review-gate` (gitignored). The fingerprint is the **git tree hash
of "HEAD + every pending change"** (computed via a throwaway index, so it equals what `git add -A && git
commit` would record). It is therefore **staging-independent** — running `git add` after approval does
**not** invalidate it — while **any change to file content does**, forcing a re-review before the next
commit.

The gate **fails closed**: if `require-review.sh` errors on a commit (or the command form is ambiguous),
it blocks (exit 2) rather than letting the commit through. Shell aliases for commit (e.g. `gc`) are the
one thing it cannot detect.

## Workflow

```
make changes  →  run code-reviewer subagent  →  (apply fixes)  →  bash .claude/hooks/record-review.sh  →  git commit
```

If the reviewer is not run, `git commit` is blocked with instructions.

## Conscious override (trivial, no-code commits only)
```bash
REVIEW_GATE_OVERRIDE=1 git commit -m "docs: fix typo"
```
The override is logged. Use it only for changes that genuinely don't warrant a code review.

## Files
| File | Role |
|------|------|
| `.githooks/pre-commit` | fmt + validate hard gate |
| `.claude/settings.json` (`hooks.PreToolUse`) | registers the review gate on `git commit` |
| `.claude/hooks/require-review.sh` | blocks un-reviewed commits |
| `.claude/hooks/record-review.sh` | records approval for the current tree |
| `.claude/hooks/_fingerprint.sh` | shared tree-fingerprint function |
| `.claude/review-gate` | local approval stamp (gitignored) |
