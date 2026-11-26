# Intent: Round 3 cuts — the duplicate template witness, the unused code-review rule, pr-adr-line, and the round 2 leftovers

**Issue:** #187 · **Type:** system-change

**Touches:** `["tests/validate.sh", ".github/workflows/gate.yml", "AGENTS.md", "CONTEXT.md", "CLAUDE.md", "REVIEW.md", "docs/adr/**", "docs/engineering-workflow.md", "docs/training/onboarding-runbook.md", "plugin/skills/dispatch/SKILL.md", "plugin/skills/intent-conversation/SKILL.md", "plugin/templates/new-project/**", "intent/187-round3-cuts/**"]`

## Problem

The 2026-11-21 before/after eval (Fable 5.2) measured round 2 and found these parts with no measured use:

1. **The duplicate template-witness row.** The root witness row at `tests/validate.sh:324` reruns the scaffolded template witness. Together with the in-place row at `:369`, the two take about 58 of the 63 s. The other 55 rows take about 5 s. CI's `template` job already runs scaffold, gate and witness on 3 OS on every PR and push.
2. **The "two axes" code-review rule.**
   - `REVIEW.md:26`, `docs/engineering-workflow.md:12`, `:262` and `:357`, and template `REVIEW.md:25` require the `mattpocock-skills:code-review` skill's two axes on every diff.
   - There are 0 `Skill` calls to it in 187 transcripts. Dispatch, which runs QC, never names it.
   - The rule contradicts ADR 0008's one review lane.
3. **`pr-adr-line`.**
   - It has 1 real CI FAIL in 168 runs: PR 102, which has stayed open and red for 39 days, so the FAIL changed nothing.
   - 40 of 61 `ADR:` lines say `none`.
   - It costs the `edited` trigger (and the duplicate runs it causes), the PR-body fetch, a `skipped:` line in every local and push run, 3 witness rows, and a `jq` clause in dispatch's merge gate.
4. **Round 2 leftovers.**
   - `CLAUDE.md` states as fact that orchestrator sub-agents run in Code Mode. #184 withdrew that claim.
   - `CLAUDE.md` lacks the herdr-server clause: a pane takes its environment from the herdr server.
   - `CLAUDE.md:12` lists `/to-spec`.
   - `tests/validate.sh:3` still cites `intent/9-test-stage/spec.md` as "the requirement, verbatim".
   - #182's condition (c) has no command.
   - Move 5 does not say what to do while the push run after a skipped merge is still pending.

## Desired outcome

- **Witness.** The root witness no longer has the scaffolded-copy template witness row. The in-place template witness row stays. `--witness` takes about half its current time.
- **Review rule.** No live doc or template requires the `code-review` skill's two axes. Review is the one adversary pass of ADR 0008, and the skill stays available.
- **`pr-adr-line`.** It is gone from both gates: the check, the `CHECKS` list, its run, its witness rows, and the `<pr-body-file>` argument. The `edited` trigger and the PR-body fetch are gone from both `gate.yml` files, along with the `jq` clause that existed only for duplicate runs.
  - The rule "every PR body carries an `ADR:` line" is withdrawn in ADR 0005 (amended, not superseded) and everywhere it is restated.
  - Whether a decision needs an ADR stays the adversary's compliance judgement. A PR body may still name the ADRs it records.
- **`CLAUDE.md`.**
  - The sub-agent sentence says this is not documented and should be treated as possible.
  - One clause covers the herdr server: workers stay off only while herdr itself was started without the variable.
  - `/to-spec` leaves the list.
- **`tests/validate.sh:3`** cites ADR 0008 and the intents, not the spec.
- **Dispatch Move 5.**
  - Condition (c) has one command: `git show origin/<base>:.github/workflows/gate.yml | grep -qE '^[[:space:]]+push:'`.
  - A pending or unreported push run means update as today.
- **The merge hold is unchanged.** `LANE_HOLD` and the `flagged:` line keep their meaning, and root and template gates stay in parity.

## Scope

- `tests/validate.sh` and `plugin/templates/new-project/files/tests/validate.sh`: remove `pr-adr-line` and its witness rows, remove the scaffolded-copy template witness row (root only), and fix the header.
- Both `gate.yml` files: drop `edited` and the PR-body step. PR and push events both run the range gate.
- Text: `AGENTS.md`, `CONTEXT.md`, `REVIEW.md` (root and template), `docs/engineering-workflow.md` (root and template), the runbook, template `AGENTS.md`, ADR 0005 (amendment with a dated status line), `intent-conversation` Move 5 (the `ADR: none` ending), the dispatch worker brief and merge gate, and `CLAUDE.md`.

## Non-goals

- No change to the merge hold, the adversary, the labels, or the review log (its dated test ends 2026-11-30, #121).
- No path filter on the `template` CI job: it adds text (eval item 4, not taken).
- No change to `skills-lock.json` (the vendored skill list).
- No consumer edits, no release (that follows this PR), and no change to PR 102 or the `claude-harness` branch.

## Acceptance criteria

- `bash tests/validate.sh origin/main..HEAD` exits 0 and prints `flagged: yes`.
- `bash tests/validate.sh --witness` exits 0. Paste the row count and wall time before (on `efa9dd4`: 57 rows, about 63 s) and after.
- `bash plugin/templates/new-project/files/tests/validate.sh --witness` exits 0.
- `git grep -nE 'pr-adr-line|ADR: none' -- ':!intent/' ':!handoffs/' ':!docs/verify/' ':!docs/adr/000[1-4]*' ':!docs/adr/000[6-8]*'` prints only ADR 0005's amendment and history lines.
- `git grep -n 'two axes' -- ':!intent/' ':!handoffs/'` prints nothing.
- `grep -n 'edited' .github/workflows/gate.yml plugin/templates/new-project/files/.github/workflows/gate.yml` prints nothing.

## System-intent alignment

"Everything earns its place": every item removes more than it adds. Each item names its own test on #121: witness time; adversary finding rate over the next 10 PRs; decisions recorded without an ADR, with the adversary as detector.
