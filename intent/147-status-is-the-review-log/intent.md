# Intent: STATUS.md becomes the review log; cmu acknowledges by the sha in the line

**Issue:** #147 · **Type:** system-change

**Touches:** `["STATUS.md", "AGENTS.md", "REVIEW.md", "README.md", "docs/engineering-workflow.md", "docs/adr/0005-auto-merge-on-green.md", "docs/training/onboarding-runbook.md", "docs/verify/cmu-pickup.md", "handoffs/README.md", "handoffs/pickup-handoff.md", ".pi/agents/adversary.md", "plugin/skills/cmu/SKILL.md", "plugin/skills/intent-conversation/SKILL.md", "plugin/templates/new-project/files/STATUS.md", "plugin/templates/new-project/files/AGENTS.md", "plugin/templates/new-project/files/README.md", "plugin/templates/new-project/files/docs/engineering-workflow.md", "plugin/templates/new-project/files/docs/adr/0001-adopt-engineering-workflow.md", "plugin/templates/new-project/files/.pi/agents/adversary.md"]`

Sean, 2026-10-18: "A for final change" (design A of the comparison on #147's thread). Runs after #146, which removes the `engineering-workflow` skill.

## Problem

See #147:
- The board has been stale since 2026-09-13.
- `cmu`'s acknowledgement rule marks an unreviewed merge as reviewed when merges overlap. This was reproduced: an acknowledgement opened at X, a worker merged Y, then the acknowledgement merged Z, so Y was wrongly marked reviewed.

## Desired outcome

- **`STATUS.md` is the review log only.** It has a two-line header that says what the file is for, then one appended line per acknowledgement: `reviewed through <40-hex sha> on <YYYY-MM-DD>`. The board text is removed. Workers and agents never write it; the developer acknowledges a review.
- **The `cmu` rule, replacing the "newest commit that changes only `STATUS.md`" rule:**
  > The acknowledgement is the sha in a `reviewed through <40-hex sha> on <date>` line of `STATUS.md` on `origin/<default>`. Of the shas that are ancestors of `origin/<default>`, take the one furthest along first-parent history. Review owed is every first-parent commit after it that touches a review path, except commits that change only `STATUS.md`. A sha not on the default branch, or a commit's position, acknowledges nothing. With no valid line: "no acknowledgement yet; showing since `<anchor>`".
- **`cmu` since-anchor 3:** the commit date of the acknowledged sha, not the newest `STATUS.md` commit. `cmu` stops reading a board snapshot from `STATUS.md`; the tracker is the snapshot.
- **ADR 0005 amendment** (the ADR 0004 "Amended" form):
  > A human acknowledges post-hoc review by appending `reviewed through <sha> on <date>` to `STATUS.md` in a commit that changes only that file. It covers exactly the default-branch history up to `<sha>`, never what merged while the line was in review.

  The same in `REVIEW.md`.
- **`AGENTS.md` "Start here":** say "catch me up" (`cmu`) for the live picture. `STATUS.md` is the review log. Do the same in the template `AGENTS.md` and `README.md`.
- **`intent-conversation`:** it stops reading `STATUS.md` for context. Its `STATUS.md` + `AGENTS.md` precondition stays.
- **Every place that still calls `STATUS.md` a board** changes to "review log": the files in Touches, root and template, including the adversary agent ("the board is the acknowledgment record").
- **The template's `STATUS.md`** becomes the two-line header with no entries.

## Non-goals

- `tests/validate.sh`, the consumer gate, `LANE_*`, `RECORDS_ONLY`, the template `shape` check, and `new-project` and `intent-conversation` detection. No gate, check or regex changes. Leave the "board" comments in `tests/validate.sh` as they are.
- History: ADR 0003, `intent/`, the dated `handoffs/` notes.
- Any claim, lock or in-progress mechanism (a #121 watch).

## Acceptance criteria

- The race, in a scratch repo with a local bare remote, following the new `cmu` text by hand:
  1. an acknowledgement opened at X with "reviewed through X";
  2. a worker change merged as Y;
  3. the acknowledgement merged as Z.

  The new rule gives "review owed: Y". The old rule would give nothing owed. Also: a stale acknowledgement rebased after a newer one never moves the acknowledgement backward. Paste the commands and the reasoning.
- `git grep -niE 'live board|single live board|the board' -- '*.md' ':!intent' ':!handoffs/2*' ':!docs/adr/0003*'` finds no sentence that calls `STATUS.md` a board. Paste the output.
- `bash tests/validate.sh --witness` passes unchanged. `bash tests/validate.sh origin/main..HEAD <body>` exits 0 with `flagged: no`.
- Release note text for consumers (on the PR): replace the board text in `STATUS.md` with the review-log header. Keep the file, because the consumer gate's `shape` check requires it.

## System-intent alignment

The live picture is derived (`cmu`), and the only hand-written status is a human's review acknowledgement, which stays correct under parallel merges.
