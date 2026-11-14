# Intent: CI proves the full suite; local suite runs never block the developer's session

**Issue:** #176 · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/tests/validate.sh", "plugin/templates/new-project/files/.github/workflows/gate.yml", "tests/validate.sh", "plugin/skills/dispatch/SKILL.md", "docs/engineering-workflow.md", "README.md", "plugin/.claude-plugin/plugin.json"]`

## Problem

Sean Cozart, 2026-11-13: "let the user work and move quickly, just move the tests
that are tied to the merged PRs within the CI".

- The suite runs up to three times per ticket: the worker, QC, then CI.
  Orchestration rule 4 (`docs/engineering-workflow.md:438`) makes the orchestrator
  run the full suite itself before it blesses a ticket.
- Measured at $0 from the cozystudio transcripts (2026-10-17 to 10-24): 37 local
  full-suite runs in the developer's main session, median 92 s, max 601 s, 80 min
  over about 14 tickets. CI `gate` there: median 214 s (n=30).
- QC takes `lane:` and `flagged:` from the branch's own `tests/validate.sh`
  (`dispatch/SKILL.md:130-131, 155-157`). A PR that edits the script can print
  `flagged: no` and clear its own merge hold. This is true today.
- In a private repo on the free plan (cozystudio), GitHub enforces no check, so
  only Move 5's text stops a merge on a red or pending `gate`.

## Desired outcome

- **Worker:** runs `bash tests/validate.sh --fast origin/<base>..HEAD`, the tests
  for the code it touched, and the fail-first pair for a fix. It pushes and hands
  off. It does not run the full suite. If `--fast` exits 2, the repo has the old
  script: the worker runs it without `--fast`.
- **`--fast`** (template `tests/validate.sh`): runs every check except
  `app-tests`, and prints `deferred: app-tests — CI gate is the proof`. It never
  prints `ok: app-tests`.
- **QC (Move 5):**
  - runs the acceptance commands; an acceptance command that is the
    `**App tests:**` command is read from CI, not run again;
  - computes `lane:` and `flagged:` with `origin/<base>`'s `tests/validate.sh
    --lane` on the fetched head, never with the PR's own script;
  - at QC start, starts **one** local full run (`bash tests/validate.sh
    origin/<base>..HEAD`) in the background. Its limit is the repo's own
    `gate.yml` `timeout-minutes`, read at QC time. No result within the limit,
    or a non-zero exit, is red: QC stops it and sends the tail of the output to
    the same worker. The recipe does not use `timeout(1)`, which stock macOS
    does not have;
  - reviews while CI runs, and reads `gate` last, right before close. QC does
    not idle-wait on CI.
- **Merge:** in the background, so the CI wait never blocks the developer's
  conversation:
  `gh pr checks <pr> --watch --fail-fast && gh pr merge --squash --match-head-commit <sha> <pr>`.
  The merge needs all five: QC passed; base-lane `flagged: no`; the background
  local run green; the checks line exited 0; the stale check (unchanged) passed.
  Whichever background job finishes last triggers the merge. "No checks
  reported" is retried at most 3 times, then it is red and goes to the developer.
  A red CI run after handoff goes back to the same worker.
- **No CI:** a repo with no `.github/workflows/gate.yml` keeps today's rule: QC's
  local run is the proof of the suite.
- **Close:** pastes the `gate` check lines and run URL, the tail of the local
  run, and the base-lane lines.
- **Template `gate.yml`:** `timeout-minutes: 30`.
- **New ADR 0007** (in this records PR) replaces Orchestration rule 4. The
  workflow doc's rule 4 becomes one line that points to it.

## Scope

- Template `tests/validate.sh`: `--fast`, with fail-first witnesses.
- Root `tests/validate.sh`: a witness that the template `gate.yml` never passes
  `--fast`, and a witness for the base-lane rule (a branch that rewrites the
  script to print `flagged: no` is still `flagged: yes` under the base script).
- Template `gate.yml`: `timeout-minutes: 30`.
- `dispatch/SKILL.md`: the worker brief and Move 5, as above.
- `docs/engineering-workflow.md` rule 4, and `README.md` only as the sync rule
  requires.
- `plugin.json` version.
- Reference only, not the PR: the draft in
  `cozysuite/review/reports/verify-ci-design/` (`validate.sh.patch`,
  `dispatch-move5.md`). Rebuild from this intent on `main`.

## Non-goals

- The content hold on a changed `**App tests:**` line (B-min item 2). It needs
  the operator's ADR 0005 amendment and ships in the next PR.
- The adversary clause for the files the App tests command runs (item 6), and
  review tiers: later steps of the agreed plan.
- Updating cozystudio's `tests/validate.sh` to the new template: its own held
  cozystudio ticket, filed after this merges.
- Moving the acceptance commands into CI, or green CI as the verdict (rejected
  Stages 2 and 3). QC and the adversary stay the verdict.
- GitHub Pro or rulesets for private consumer repos: the operator's cost call.

## How this PR is reviewed (bootstrap)

This PR edits the machinery that reviews it:
- QC of this PR follows Move 5 as it is on `main`. The orchestrator's checkout
  stays on `main` until merge, because `.claude/skills/` are symlinks into
  `plugin/skills/` in the working tree.
- QC applies the base-lane rule by hand: `git show origin/main:tests/validate.sh`
  into the QC clone's git dir, then `--lane origin/main..HEAD` on the head, with
  the output pasted.
- The PR is held (`tests/validate.sh`, template `gate.yml`): a named human
  merges.

## Acceptance criteria

- In a freshly scaffolded repo with an `**App tests:**` line, `bash
  tests/validate.sh --fast origin/main..HEAD` prints `deferred: app-tests — CI
  gate is the proof` and no `ok: app-tests`. Fail-first: the template
  `--witness` has rows that fail when `--fast` prints `ok:` or runs the command.
- A root witness fails when the template `gate.yml` passes `--fast`.
- A root witness: under `origin/<base>`'s script, a branch that rewrites
  `tests/validate.sh` to print `flagged: no` is `flagged: yes`.
- Template `gate.yml` has `timeout-minutes: 30`.
- `dispatch/SKILL.md` says, checkably: the worker runs `--fast` with the exit-2
  fallback; the base-lane rule; the one background local run with the
  `timeout-minutes` limit and timeout-is-red; the merge line and its five
  conditions; the 3-try cap; the no-`gate.yml` fallback; red CI back to the same
  worker; "a check that did not run is never proof".
- `docs/engineering-workflow.md` rule 4 points to ADR 0007.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0 with `flagged: yes`,
  and `--witness` ends `0 unexpected`.
- **Accuracy (needs the developer's OK for model cost and a throwaway private
  repo):** in a repo made by `new-project`, with dispatch loaded from this
  branch, two tickets each carry one seeded defect: (1) a full-suite-only failure
  with QC finished while `gate` is pending; (2) GNU-only syntax in a path only
  the full suite tests. Neither merges, and each close shows the check that
  stopped it.
- **Speed and reliability (after merge, recorded on #123):** the next 3 real
  cozystudio tickets, measured with `T_handoff`, `T_gate`, `T_qc_ready` and
  `T_close`. Revert to `golden-main-1.8.1-2026-11-14` if, on 2 of 3:
  `T_close − T_handoff` is longer than arm A's median from the PR timelines; or
  any suite run is in the developer's foreground; or any merge lands on a
  pending or red `gate`.

## System-intent alignment

Rule 3 gets stronger: proof is the CI run on the head SHA plus the local run on
the developer's OS, a check that did not run is never proof, and a PR can no
longer clear its own hold. Rule 5 is kept by the no-CI fallback.
