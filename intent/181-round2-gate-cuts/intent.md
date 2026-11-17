# Intent: One review lane, no spec.md, four dead checks gone, and main proven after every merge

**Issue:** #181 · **Type:** system-change

**Touches:** `["tests/validate.sh", ".github/workflows/gate.yml", "README.md", "AGENTS.md", "CONTEXT.md", "REVIEW.md", "docs/engineering-workflow.md", "docs/adr/**", "docs/training/onboarding-runbook.md", "intent/TEMPLATE-spec.md", "intent/181-round2-gate-cuts/**", ".pi/agents/adversary.md", ".claude/verify-host.md", "plugin/skills/dispatch/SKILL.md", "plugin/skills/intent-conversation/SKILL.md", "plugin/skills/new-project/SKILL.md", "plugin/templates/new-project/**"]`

## Problem

Parts of the gate decide nothing (2026-11-15 eval, verified; 2026-11-16 peer review):

- Lane tiers: merged PR bodies show 73 T2, 3 T1, 0 T0 here and 25 of 25 T2 in cozystudio. The T0/T1 code is about 60 lines and about 37 of 101 witness rows.
- `dispatch-hold` and `herdr-retire` grep one fixed sentence each, with 0 real FAILs. That is the class #133 cut.
- `sync-rule` and `stage-parity` exist only to keep README's stage list a copy of `docs/engineering-workflow.md`. 36 commits paid a forced README edit for it.
- `spec.md`: 0 in cozystudio's 28 intents, 5 here, the last added 2026-09-13.
- The root `.github/workflows/gate.yml` runs only on `pull_request`. Nothing proves `main` after a merge. The scaffold template already has the `push` trigger.

## Desired outcome

- Every PR gets one read-only adversary pass. There are no T0/T1 tiers and no lighter review budget anywhere in the gate, skills or docs.
- The `flagged: yes|no` merge hold (ADR 0005, `LANE_HOLD`) is unchanged in meaning and output.
- `dispatch-hold`, `herdr-retire`, `sync-rule` and `stage-parity` are gone from `CHECKS`, `default_run`, their functions and their witness rows.
- README's stage list is one pointer line to `docs/engineering-workflow.md`.
- `intent/TEMPLATE-spec.md` (root and template) is gone, and `intent-layout` no longer reads `spec.md`. The two historical `spec.md` files stay as records.
- The root gate runs on `push` to `main`.
- One new ADR supersedes ADR 0001 and ADR 0003. ADR 0005's text names the hold flag, not tiers.
- Root and scaffold-template gates stay in parity (`template-gate-parity` green).

## Scope

- `tests/validate.sh` and `plugin/templates/new-project/files/tests/validate.sh`: remove the tier logic (`LANE_LIGHT`, `LANE_FLOOR_T1`, the T0/T1 branches, the version-only floor) and its witness rows; keep `--lane`, `LANE_HOLD` and the `flagged:` line.
- `.github/workflows/gate.yml`: add `push: branches: [main]`.
- Docs and skills that name tiers or `spec.md`: README, AGENTS.md, CONTEXT.md, REVIEW.md, the workflow doc, the runbook, the adversary agent, `.claude/verify-host.md`, `dispatch` Move 5, `intent-conversation` Move 5, `new-project`, and the template copies.

## Non-goals

- No change to dispatch's stale check or the herdr probe. That is #182.
- No change to the post-merge review log. Its dated test ends 2026-11-30 (#121).
- No change to the labels, the merge hold or the adversary prompt beyond removing tier wording.
- No edits to consumer repos. cozystudio gets the template change only by its own later update.
- No changes to the `claude-harness` branch.
- No release or version bump.

## Acceptance criteria

- `bash tests/validate.sh origin/main..HEAD` exits 0 and prints `flagged: yes` (this PR touches held files).
- `bash tests/validate.sh --witness` exits 0. The row count is lower than before (101 on `golden-main-1.9.0-2026-11-16`); paste both counts and both wall times.
- `git grep -nwE 'T0|T1|LANE_LIGHT|LANE_FLOOR_T1' -- ':!intent/' ':!handoffs/' ':!docs/verify/' ':!docs/adr/000[1-7]*'` prints nothing.
- `git grep -n 'TEMPLATE-spec' -- ':!intent/' ':!handoffs/' ':!docs/adr/'` prints nothing.
- `.github/workflows/gate.yml` has a `push` trigger on `main`.
- The new ADR is listed, and ADR 0001 and 0003 carry `Superseded by` lines.

## System-intent alignment

It applies "everything earns its place" and SYSTEM-INTENT's "How the system changes" rule: what has no measured use is cut, with the golden tag as the way back.
