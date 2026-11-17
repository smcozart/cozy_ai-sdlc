# Intent: Dispatch skips a stale update when it cannot matter, and herdr workers drop the probe

**Issue:** #182 · **Type:** system-change

**Touches:** `["plugin/skills/dispatch/SKILL.md", "docs/engineering-workflow.md", "intent/182-stale-skip-probe/**"]`

Blocked by: #181

## Problem

- **Stale updates.** Dispatch Move 5 makes the worker update the branch and re-run the proof every time `<base>` moves. History: 12 updates on 8 merged PRs, 11 gate reruns, 0 red. In arm B (#123) this cost 4.2 of 18.3 min, and PR 79 and PR 80 shared no file. With N parallel workers, each merge makes N−1 green proofs stale, so merges serialize at one CI run each (cozystudio gate median 228 s).
- **The herdr probe.** The herdr worker still runs the guardrail probe, but continues whatever the result. Of 7 herdr workers, 6 reported "not denied". 5 of those ran `az account show` on a machine without `az` (exit 127), and the one "denied" came from an unrelated hook.

## Desired outcome

- Move 5 skips the update and rerun only when all of these hold. Otherwise it updates as today.
  - (a) The PR's files and the files changed on `origin/<base>` since the merge-base are disjoint.
  - (b1) That base delta is `flagged: no` under `origin/<base>`'s own `tests/validate.sh --lane`.
  - (b2) The PR and the base delta do not both add a file under `docs/adr/`.
  - (c) `origin/<base>`'s `.github/workflows/gate.yml` runs on `push` to `<base>`, so the combined tree is proven one CI run after the merge.
- The skip text names its limit: a break between file-disjoint PRs (an app test, `skill-links`, `adr-refs`, `agents-commands`) shows on the push-to-base gate run. The first red gate on `<base>` from a skipped update reverts this rule.
- The merge still uses `--match-head-commit <the head SHA QC ran on>`.
- The herdr row and the herdr brief no longer run or report the probe. The `herdr pane: supervised` first line, the normal permission mode and the "never a bypass mode" rule stay. Other hosts keep the probe unchanged.

## Scope

- `plugin/skills/dispatch/SKILL.md`: Move 3's herdr paragraph, Move 5's stale paragraph, and the herdr brief.
- `docs/engineering-workflow.md`, only where it restates either rule.

## Non-goals

- No gate code. The push trigger and the lane cuts land in #181.
- No change to the probe on non-herdr hosts.
- No consumer edits and no release.
- No changes to the `claude-harness` branch.

## Acceptance criteria

- `bash tests/validate.sh origin/main..HEAD` exits 0 with `flagged: no`.
- `git grep -n 'probe' plugin/skills/dispatch/SKILL.md`: every hit is outside the herdr row and the herdr brief.
- Move 5 states the guard's four conditions (a, b1, b2, c), the named limit and the revert rule. The adversary confirms them against this intent.
- Earned-test, recorded on #182 at merge: the next 10 parallel PRs in cozystudio, with skipped updates and minutes saved. The first red gate on base from a skipped update reverts the rule.

## System-intent alignment

Speed with a bounded, self-reverting reliability cost, and less text in the brief. This serves "everything earns its place".
