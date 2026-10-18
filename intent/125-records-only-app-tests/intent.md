# Intent: the consumer gate skips app tests on a records-only range

**Issue:** #125 · **Status:** approved · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/tests/validate.sh", "plugin/templates/new-project/files/AGENTS.md"]`

Reported by the cozystudio session, 2026-10-18. The developer approved on 2026-10-18 ("Yes to 1 and 2") after the evidence below. Evidence for #123.

## Problem

The consumer gate (`plugin/templates/new-project/files/tests/validate.sh`) runs the `**App tests:**` command on every range. A records-only PR changes no code, but it pays the full app test cost three times: the local gate, the PR run in CI, and the push-to-main run in CI.

Evidence (#125 comments):

| Repo | Records-only gate, local | CI gate job | `FAIL: app-tests` on a records-only range |
|---|---|---|---|
| cozystudio | 262 s (session 02202fed) | 277–398 s, 2 runs per records PR | 0 |
| cozy_view | 14–15 s, app tests about 95% | 20–37 s | 0 |

cozy-view read 272 local gate runs (2026-09-27 to 2026-10-18). Many runs cannot be classified, so 0 failures means no counter-evidence, not proof. No cozystudio test reads `intent/`, `handoffs/`, `docs/` or `STATUS.md`.

## Desired outcome

When the gate is given a range and every path in it matches the records set, it prints `skipped: app-tests — records-only diff` and does not run the command. In every other case `app-tests` runs as it does now.

## Scope

- One records rule in the template gate: `RECORDS_ONLY='^(intent/|handoffs/|STATUS\.md$)'`, which a repo extends the same way it extends `LANE_LIGHT` (safe by omission).
- The skip applies only to `app-tests`. `shape`, `intent-layout`, `adr-numbering` and `pr-adr-line` always run.
- `app-tests` runs when: no range is given; the range is empty or git cannot read it; any path in the range (or an untracked or dirty file) is outside the set; or the range deletes a file.
- The template `AGENTS.md` says in one line that records-only ranges skip app tests, and how a repo adds a path.

## Non-goals

- Making "records-only" a lane. The lane classifier stays as it is (`intent/` is outside `LANE_LIGHT`).
- This repo's own gate (`tests/validate.sh` at the root). It has no app tests.
- Skipping the local gate run in the loop (option 2 on #125).
- Speeding up cozystudio's own tests (`--test-concurrency=1`). That is cozystudio's change.

## Acceptance criteria

- Witnesses in the template's `--witness` mode, each on a temp repo:
  - a range with only `intent/` and `STATUS.md` paths, and `**App tests:** \`false\``: prints `skipped: app-tests`, exit 0;
  - the same range plus one code file: `FAIL: app-tests`;
  - no range given, `**App tests:** \`false\``: `FAIL: app-tests`;
  - a records-only range that deletes a file: `app-tests` runs.
- `bash plugin/templates/new-project/files/tests/validate.sh --witness` passes, and so does the root `tests/validate.sh --witness`.
- `tests/validate.sh origin/main..HEAD` passes on the ticket range.
- The PR is held for the developer's review (the template gate is on the hold list).

## System-intent alignment

Serves the evidence rule for change (#119): the change rests on measured cost and zero observed failures, and it removes time without removing a check that could catch a defect.
