# Intent: the records-only skip costs no quality, and we can see it

**Issue:** #128 · **Status:** draft · **Type:** system-change

**Touches:** `["tests/validate.sh", "REVIEW.md"]` (part 1 only; part 2 is a watch, no code)

Sean, 2026-10-18, on merging #127: "we need to make sure we aren't sacrificing any quality with this change."

## Problem

#127 (#125) lets the consumer gate skip `app-tests` on a records-only ticket range. Two gaps remain:

1. The root `LANE_HOLD` (`tests/validate.sh:42`) names only the root gate. A change to the consumer gate (`plugin/templates/new-project/files/tests/validate.sh`) or its workflow prints `flagged: no`, so it can merge on green. #127 got a human merge only because its intent said so.
2. Nothing records whether the skip ever let a defect through.

## Desired outcome

1. Any change to the template gate, its workflows or its hooks prints `flagged: yes`, and a named human merges it.
2. A miss is a push-to-main `app-tests` failure in a consumer right after a PR whose PR run skipped app tests. Misses are counted over a fixed window. One miss reverts #127.

## Scope

- Part 1: add `plugin/templates/new-project/files/tests/validate.sh`, `plugin/templates/new-project/files/.github/workflows/` and, if present, `plugin/templates/new-project/files/.githooks/` to the root `LANE_HOLD`. Add one witness row (a mutation of the template gate prints `flagged: yes`). Update the hold list in `REVIEW.md`.
- Part 2: over the first 20 records-only PRs across consumers or 30 days, whichever ends first, read `gh run list -R <repo> --workflow gate` for cozystudio and cozy_view. Count the misses and the seconds saved. Post them on #128 and #123.

## Non-goals

- Changing the skip itself (#125, done in #127).
- Fixing the known limits accepted in #127. Part 2 watches them.
- The app-test location question (#112).

## Acceptance criteria

- Part 1: `bash tests/validate.sh --witness` passes with the new row, and the row fails on main before the change. `bash tests/validate.sh --lane` on a range that touches the template gate prints `flagged: yes`. `bash tests/validate.sh origin/main..HEAD` exits 0.
- Part 2: a comment on #128 with the window, the PRs read, the miss count and the time saved. With one miss: #127 is reverted (`git revert d0cbb8b`, or restore tag `golden-main-1.6.0-2026-10-18`), and #125 is reopened with the run link.

## System-intent alignment

Serves the evidence rule for change (#119): the skip stays only while evidence shows it costs no quality.
