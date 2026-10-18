# Intent: the records-only skip costs no quality, and we can see it

**Issue:** #128 · **Status:** draft · **Type:** system-change

**Touches:** `["tests/validate.sh", "REVIEW.md", "AGENTS.md", "README.md", "docs/engineering-workflow.md", "docs/adr/0005-auto-merge-on-green.md", "docs/adr/0003-review-effort-follows-a-computed-lane.md", "plugin/skills/engineering-workflow/SKILL.md", ".claude/skills/engineering-workflow/SKILL.md", "plugin/skills/herdr-orchestrator/SKILL.md", ".claude/skills/herdr-orchestrator/SKILL.md", ".agents/skills/herdr-orchestrator/SKILL.md"]` (part 1 only. Part 2 is a watch, with no code.)

Sean, 2026-10-18, on merging #127: "we need to make sure we aren't sacrificing any quality with this change."

## Problem

#127 (#125, released in ai-sdlc 1.6.1) lets the consumer gate skip `app-tests` on a records-only ticket range. Two gaps remain:

1. The root `LANE_HOLD` (`tests/validate.sh:42`) names only the root gate. A change to the consumer gate prints `flagged: no`, so it can merge on green. The consumer gate is `plugin/templates/new-project/files/tests/validate.sh`, plus its workflow and the scaffolder that writes it. #127 got a human merge only because its intent said so.
2. Nothing records whether the skip ever lets a defect through.

## Desired outcome

1. Any change to the consumer gate prints `flagged: yes`, and a named human merges it. The consumer gate is the template `tests/validate.sh`, the template `.github/workflows/`, and `plugin/templates/new-project/scaffold.sh`. The hold list reads the same in the script, in ADR 0005 and in every document that names it.
2. Misses of the skip are counted over a fixed window. A confirmed miss reverts #127.

## Scope

**Part 1: the hold list**

- Add these to the root `LANE_HOLD`:
  - `plugin/templates/new-project/files/tests/validate.sh`
  - `plugin/templates/new-project/files/.github/workflows/`
  - `plugin/templates/new-project/scaffold.sh`
- ADR 0005 (`docs/adr/0005-auto-merge-on-green.md:16-21`) says its list and the script's list are the same list. Amend ADR 0005 with the three paths, using that ADR's status-history rule. The PR's `ADR:` line names 0005.
- Update every other place that lists the hold paths, so that each one matches the script:
  - `REVIEW.md:27`
  - `AGENTS.md:39`
  - `README.md`
  - `docs/engineering-workflow.md`
  - ADR 0003
  - the `engineering-workflow` skill and its `.claude` copy
  - the `herdr-orchestrator` skill and its `.claude` and `.agents` copies

  Copies stay byte-identical.
- Two witness rows. Each must fail on main before the change:
  - a mutation of the template `tests/validate.sh` prints `flagged: yes`;
  - a mutation of the template `.github/workflows/gate.yml` prints `flagged: yes`.
- The template's own `LANE_HOLD` (`plugin/templates/new-project/files/tests/validate.sh:34`) stays as it is, because consumers have no `plugin/templates/`. Do not extend `template-gate-parity` to the new paths. Reword the parity comment (`tests/validate.sh:214`) to say "every shared hold alternative".

**Part 2: the miss watch**

- **Miss:** a push-to-main gate run on PR X's merge commit whose log (`gh run view --log`) shows `FAIL: app-tests`, where X's last PR gate run log shows `skipped: app-tests — records-only diff`, and the same failure comes back on a re-run. A failure only in a step outside `validate.sh` (for example cozystudio's `npm run test:e2e`) is not a miss.
- **Window:** it starts per consumer (cozystudio, cozy_view) at that consumer's first gate run that prints the skip line. That needs ai-sdlc 1.6.1 and the consumer updating its copy of the gate. It ends after 20 records-only PRs across consumers or 30 days from the first start, whichever comes first.
- **Saved time:** read it from the app-tests part of the gate log, not from the run duration. Most of cozystudio's job time is `npm ci`, Playwright and e2e.

## Non-goals

- Changing the skip itself (#125, done in #127).
- Fixing the known limits accepted in #127. Part 2 watches them.
- The app-test location question (#112).
- The template's documents about the consumer hold list. They do not change.

## Acceptance criteria

- Part 1:
  - `bash tests/validate.sh --witness` passes with both new rows. Both rows fail on `origin/main` before the change.
  - In a scratch worktree, `printf 'x\n' >> plugin/templates/new-project/files/tests/validate.sh; bash tests/validate.sh --lane` prints `flagged: yes`.
  - `grep -rn` finds no hold list in the files listed under Touches that differs from the script.
  - `bash tests/validate.sh origin/main..HEAD <body>` exits 0.
  - A named human merges the PR, because it changes the root gate.
- Part 2: a comment on #128 and #123 that gives the window per consumer, the PRs read, the miss count and the seconds saved. On a confirmed miss: revert #127 on main (`git revert d0cbb8b`, or restore tag `golden-main-1.6.0-2026-10-18`), cut a patch release, and reopen #125 with the run link.

## System-intent alignment

Serves the evidence rule for change (#119): the skip stays only while evidence shows that it costs no quality.
