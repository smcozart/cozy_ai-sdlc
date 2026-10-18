# Intent: cut the gate checks that only guard fixed wording and never failed

**Issue:** #133 · **Status:** approved · **Type:** system-change

**Touches:** `["tests/validate.sh", "AGENTS.md"]`

From the harness review, Sean, 2026-10-18 (item 2).

## Problem

These 5 of the 18 root gate checks grep for exact past sentences:
- `t1-trust-wording`, `t1-log-clobber` and `t1-spawn-session`, on the `herdr-orchestrator` skill;
- `t3-label-drift` and `t3-precedence`, on `AGENTS.md`.

They came from the #8 regression corpus, and their sha witnesses are in `witness_run`. They guard wording, not behavior. Every edit of those files must keep the exact sentences.

## Desired outcome

The gate keeps a check only when it guards behavior, or when it has caught a real defect.

## Decision rule (fixed before the data)

- **Data:** the cozy-view session posts on #133 the real FAIL count for each check. "Real" means a run on a real range, not `--witness`, and not a run made while the gate itself was being edited. Source: local transcripts since 2026-09-27, plus CI gate logs.
- **Cut** a check only if both are true: it is one of the 5 wording checks above, and its real FAIL count is 0.
- **Keep** a wording check that has a real FAIL. Name it and the run on #133.
- **Never cut a behavior check** under this ticket, whatever its count.
- **For each cut check**, remove its function, its `CHECKS` entry, its `default_run` line, its sha witness rows, and its line in `AGENTS.md ## Commands`. The `agents-commands` check must still pass. If `FO_OLD` and the `#8 corpus` comments are no longer used, remove them too.
- **Wait for the data.** If it is not on #133 when the worker starts, the worker stops and says so in `HANDOFF:`. It does not cut anything on a guess.

## Non-goals

- Changing any behavior check.
- The lane classifier (#135).

## Acceptance criteria

- On #133: the data table, and the cut list it leads to.
- `bash tests/validate.sh --witness` passes, with fewer witnesses by exactly the removed sha rows.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0, prints one `ok:` line per remaining check, and prints `flagged: yes`. A named human merges.

## System-intent alignment

Serves the evidence rule for change (#119): a check stays when evidence shows it earns its place.
