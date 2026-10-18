# Intent: the consumer gate skips app tests on a records-only range

**Issue:** #125 · **Status:** approved · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/tests/validate.sh", "plugin/templates/new-project/files/AGENTS.md", "intent/125-records-only-app-tests/intent.md"]`

Reported by the cozystudio session, 2026-10-18. The developer approved on 2026-10-18 ("Yes to 1 and 2") after the evidence below. Evidence for #123.

## Problem

The consumer gate (`plugin/templates/new-project/files/tests/validate.sh`) runs the `**App tests:**` command on every range. A records-only PR changes no code, but it pays the full app test cost three times: the local gate, the PR run in CI, and the push-to-main run in CI.

Evidence (#125 comments):

| Repo | Records-only gate, local | CI gate job | `FAIL: app-tests` on a records-only range |
|---|---|---|---|
| cozystudio | 262 s (session 02202fed) | 277–398 s, 2 runs per records PR | 0 |
| cozy_view | 14–15 s, app tests about 95% | 20–37 s | 0 |

cozy-view read 272 local gate runs (2026-09-27 to 2026-10-18). Many runs cannot be classified, so 0 failures means no counter-evidence, not proof. No app test in cozystudio or cozy_view reads `intent/`, `handoffs/`, `docs/` or `STATUS.md`.

This change saves the local run and the PR run. The push-to-main run in CI has no range (`gate.yml` runs `validate.sh` bare), so it still runs app tests. It stays as the backstop.

## Desired outcome

When the gate is given a range and every path in it matches the records set, it prints `skipped: app-tests — records-only diff` and does not run the command. In every other case `app-tests` runs as it does now.

## Scope

- One records rule in the template gate: `RECORDS_ONLY='^(intent/|handoffs/|STATUS\.md$)'`. A repo widens it the same way it extends `LANE_LIGHT`. `RECORDS_ONLY=''` turns the skip off, for a repo whose tests read records. The default is not empty, so the template `AGENTS.md` says this in one line.
- The skip applies only to `app-tests`. `shape`, `intent-layout`, `adr-numbering` and `pr-adr-line` always run.
- The skip is about the code that the tests run on, which is the working tree. So:
  - it applies only when the range is `A..HEAD` or `A...HEAD` and `A` resolves to merge-base(<base>, `HEAD`), so the range is the whole ticket. `<base>` is resolved as `lane_run` resolves it: `LANE_TARGET`, then the `**Base branch:**` line, then `origin/main` / `main`. A bare `HEAD` never skips (QC on #127: a bare `HEAD` or a later start hides committed code);
  - the working tree must also be clean apart from records paths. The check reads `git status --porcelain -z`, so a dirty or untracked code file runs the tests under `origin/main..HEAD` too.
- The path list reuses `lane_of`'s listing (`-z`, `--no-renames`, no quoting), with its delete and symlink results. It does not run a second `git diff --name-only`. That listing must run before `app-tests`.
- `app-tests` runs when:
  - no range is given;
  - the range is empty or git cannot read it;
  - the range's end is not `HEAD`, or the range is a bare `HEAD`;
  - the range's start is not merge-base(<base>, `HEAD`), the base branch cannot be found, or the `**Base branch:**` line is unreadable;
  - any path in the range or the working tree is outside the set;
  - the range deletes a file;
  - any entry is a symlink or a submodule (mode `160000`).
- The template `AGENTS.md` says in one line that records-only ranges skip app tests, how a repo adds a path, and that `RECORDS_ONLY=''` turns the skip off.

## Non-goals

- Making "records-only" a lane. The lane classifier stays as it is (`intent/` is outside `LANE_LIGHT`).
- This repo's own gate (`tests/validate.sh` at the root). It has no app tests.
- Skipping the local gate run in the loop (option 2 on #125).
- The push-to-main CI run (`gate.yml`, no range). It still runs app tests. Do not switch it to the push's before-commit: that breaks on a first push (all-zero commit) and on a force-push.
- Speeding up cozystudio's own tests (`--test-concurrency=1`). That is cozystudio's change.

## Acceptance criteria

- Witnesses in the template's `--witness` mode, each on a temp repo:
  - a range with only `intent/` and `STATUS.md` paths, and `**App tests:** \`false\``: prints `skipped: app-tests`, exit 0;
  - the same range plus one code file: `FAIL: app-tests`;
  - no range given, `**App tests:** \`false\``: `FAIL: app-tests`;
  - a records-only range that deletes a file: `app-tests` runs;
  - a rename from a code path into `intent/`: `app-tests` runs;
  - a symlink under `intent/`: `app-tests` runs;
  - `origin/main..HEAD` records-only, with an untracked `src/x.js` in the working tree: `app-tests` runs;
  - a records-only range whose end is not `HEAD` (for example `HEAD~2..HEAD~1`, or `main..<records-branch>` while on another branch): `app-tests` runs;
  - a bare `HEAD` with only `STATUS.md` dirty: `app-tests` runs;
  - a records-only `HEAD~1..HEAD` whose start is not the merge-base (a code commit sits before it): `app-tests` runs;
  - the base branch not found (`LANE_TARGET=nope`): `app-tests` runs;
  - a path with a newline in its name (`STATUS.md\nintent/x`): `app-tests` runs;
  - `RECORDS_ONLY=''` on a records-only range: `app-tests` runs.
- A `skipped: app-tests` line does not count toward `N ok` (the root gate's scaffolded-summary witness counts `ok:` lines).
- `bash plugin/templates/new-project/files/tests/validate.sh --witness` passes, and so does the root `tests/validate.sh --witness`.
- `tests/validate.sh origin/main..HEAD` passes on the ticket range.
- The PR is held for the developer's review (the template gate is on the hold list).

## System-intent alignment

Serves the evidence rule for change (#119): the change rests on measured cost and zero observed failures, and it removes time without removing a check that could catch a defect.
