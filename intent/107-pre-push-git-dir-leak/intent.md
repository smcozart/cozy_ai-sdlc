# Intent: the pre-push hook passes a green range and measures it against the base branch

**Issue:** #107 · **Status:** draft · **Type:** bug

**Touches:** `[".githooks/pre-push", "tests/validate.sh"]`

## Problem

Git exports `GIT_DIR` to hooks. `tests/validate.sh` inherits it in its temporary repos, so under `.githooks/pre-push` 13 of 14 checks fail on a green range, from any checkout. The hook also hard-codes `origin/main..HEAD` instead of the `**Base branch:**` in `AGENTS.md`.

## Desired outcome

Under the hook, a green range passes and a red range is blocked, both measured against the base branch.

## Scope

- Clear `GIT_DIR`, `GIT_WORK_TREE` and `GIT_INDEX_FILE` in the hook before the gate runs.
- Range from the **Base branch:** line, default `main`.
- A fail-first witness for the `GIT_DIR` case.

## Non-goals

- Changing any check's logic.

## Acceptance criteria

- `GIT_DIR=$(git rev-parse --git-dir) bash .githooks/pre-push` exits 0 on a green range, from the main checkout and from a worktree.
- The same command exits 1 on a range with a known red check.
- `tests/validate.sh --witness` includes the new witness and passes; reverting the fix makes that witness fail.
- A real `git push` of a green branch succeeds with no `--no-verify`.

## System-intent alignment

Keeps the local guardrail trustworthy, so it is never bypassed by habit.
