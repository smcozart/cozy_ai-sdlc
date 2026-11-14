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

**How it gets in** (SYSTEM-INTENT "How the system changes"): the hold part by
the third trigger, a merge hold that gives a wrong result, shown by this PR's
fail-first base-lane witness. The speed part by the operator's waiver of the
before-timing (2026-11-14): arm A is already measured above, and arm B with the
revert rule follows the merge. **What it replaces:** `--fast` replaces the
worker's full run; the base-lane rule replaces trusting the PR's own script;
ADR 0007 replaces Orchestration rule 4. `--deadline` adds a limit to the one
local run that is kept (for macOS); nothing else covers a hang.

## Desired outcome

- **Worker:** runs `bash tests/validate.sh --fast origin/<base>..HEAD`, the tests
  for the code it touched, and the fail-first pair for a fix. It pushes and hands
  off. It does not run the full suite. If the repo's script has no `--fast`
  (`grep -q -- '--fast' tests/validate.sh` fails), it is the old script: the
  worker runs it without `--fast`. A non-zero exit from a script that has
  `--fast` is a real failure, not a fallback.
- **`--fast`** (template `tests/validate.sh`): runs every check except
  `app-tests`, and prints `deferred: app-tests — CI gate is the proof`. It never
  prints `ok: app-tests`.
- **`--deadline <seconds>`** (template `tests/validate.sh`): the `app-tests`
  command is stopped at the limit and prints `FAIL: app-tests — deadline
  <seconds>s`. The script enforces it, so it works the same on every host and
  needs no `timeout(1)`, which stock macOS does not have.
- **QC (Move 5):**
  - runs the acceptance commands; an acceptance command that is the
    `**App tests:**` command is read from CI, not run again;
  - computes `lane:` and `flagged:` with `origin/<base>`'s script on the
    fetched head, never with the PR's own script:
    `git show origin/<base>:tests/validate.sh | bash -s -- --lane origin/<base>..HEAD`
    (a copy of the script outside the work tree exits 2 at its `cd` line);
  - at QC start, starts **one** local full run in the background:
    `bash tests/validate.sh --deadline <s> origin/<base>..HEAD`, where `<s>` is
    the `gate` job's `timeout-minutes` in the repo's own `gate.yml`, read at QC
    time, times 60. A non-zero exit, the deadline included, is red: QC sends
    the tail of the output to the same worker;
  - reviews while CI runs, and reads `gate` last, right before close. QC does
    not idle-wait on CI.
- **The CI wait** runs in the background, so it never blocks the developer's
  conversation: `gh pr checks <pr> --watch --fail-fast`, alone. Its exit is an
  event, never a merge.
- **The merge** comes when the last background job (the CI wait or the local
  run) has ended. Then, in the foreground and in this order (about 1 s, no
  wait): confirm QC passed and base-lane `flagged: no`; confirm the local run
  exited 0; confirm `gate` itself passed on the head SHA (`gh pr checks <pr>
  --json name,bucket` has `gate` with `bucket` `pass`; `gh pr checks` alone
  exits 0 when `gate` is not reported yet, or skipped); run the stale check
  (unchanged); then `gh pr merge --squash --match-head-commit <sha> <pr>`.
  `gate` not reported is retried at most 3 times, then it is red and goes to the
  developer. A red CI run after handoff goes back to the same worker.
- **Hosts without background jobs** (no completion notice, for example pi by
  hand): QC runs the CI wait and the local run in the foreground, as today.
  The proof rules are the same; only the wait is not hidden.
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
- QC applies the base-lane rule by hand, from the QC clone:
  `git show origin/main:tests/validate.sh | bash -s -- --lane origin/main..HEAD`,
  with the output pasted.
- The PR is held (`tests/validate.sh`, template `gate.yml`): a named human
  merges.

## Acceptance criteria

- In a freshly scaffolded repo with an `**App tests:**` line, `bash
  tests/validate.sh --fast origin/main..HEAD` prints `deferred: app-tests — CI
  gate is the proof` and no `ok: app-tests`. Fail-first: the template
  `--witness` has rows that fail when `--fast` prints `ok:` or runs the command.
- With `**App tests:** sleep 30`, `bash tests/validate.sh --deadline 1` prints
  `FAIL: app-tests — deadline 1s` and exits non-zero within 5 s. A template
  witness row checks it.
- A root witness fails when the template `gate.yml` passes `--fast`.
- A root witness: under `origin/<base>`'s script, a branch that rewrites
  `tests/validate.sh` to print `flagged: no` is `flagged: yes`.
- Template `gate.yml` has `timeout-minutes: 30`.
- `dispatch/SKILL.md` says, checkably: the worker runs `--fast` with the
  old-script fallback; the piped base-lane recipe; the one background local run
  with `--deadline` from the `gate` job's `timeout-minutes`; the CI wait and the
  merge are separate commands, and the merge is in the foreground after the
  last background job; `gate` itself must be `pass`; the 3-try cap; the
  no-`gate.yml` fallback; the foreground fallback for hosts without background
  jobs; red CI back to the same worker; "a check that did not run is never
  proof".
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
  `T_close`. Arm A for the same metric is taken at $0 from earlier cozystudio PR
  timelines (last push to merge) before arm B starts. Revert to
  `golden-main-1.8.1-2026-11-14` **at once** on any single merge on a pending
  or red `gate`. Revert if `T_close − T_handoff` is longer than arm A's median
  on 2 of 3, or if a suite run is in the developer's foreground on 2 of 3. One
  foreground run is a Move 5 text defect, fixed in a follow-up ticket.

## System-intent alignment

Rule 3 gets stronger: proof is the CI run on the head SHA plus the local run on
the developer's OS, a check that did not run is never proof, and a PR can no
longer clear its own hold. Rule 5 is kept: the deadline is in the script, the
base-lane recipe is one shell line, and hosts without background jobs keep the
same proof in the foreground.
