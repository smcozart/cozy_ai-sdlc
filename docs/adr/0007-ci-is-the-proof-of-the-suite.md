# CI is the proof of the suite; the local run moves off the developer's critical path

**Issue:** #176 · **Status:** accepted with the operator's approval of #176 ·
**Intent:** `intent/176-ci-proves-the-suite/intent.md`; replaces Orchestration
rule 4 in `docs/engineering-workflow.md` ("Run acceptance criteria and the full
suite yourself before blessing").

The full suite ran up to three times per ticket (worker, QC, CI), and the QC run
blocked the developer's conversation: 37 runs, median 92 s, 80 min over about
14 cozystudio tickets (transcripts, 2026-10-17 to 10-24). **Decision:**

- **The CI `gate` run on the head SHA is the proof of the suite** on the CI OS,
  from a clean checkout. It also catches what a local run hides (untracked
  files, a warm cache, `node_modules` drift).
- **QC's one local full run is the proof on the developer's OS.** It runs in the
  background, never in the developer's foreground. A macOS-only failure has
  happened (cozystudio #7, a hang), so this run is kept, not removed. Its limit
  is the repo's own `gate.yml` `timeout-minutes`.
- **The worker runs `--fast`**, the tests for the code it touched and the
  fail-first pair, and hands off.
- **The orchestrator's terminal proves the hold and the review.** `lane:` and
  `flagged:` come from `origin/<base>`'s `tests/validate.sh --lane` on the
  fetched head, never from the PR's own script.
- **A check that did not run is never proof.** Deferred, skipped, pending,
  timed out, "no checks reported" and inconclusive are all not proof. Only a run
  that printed `ok:` on the head SHA is.
- **The merge is fail-closed in one command:** `gh pr checks <pr> --watch
  --fail-fast && gh pr merge --squash --match-head-commit <sha> <pr>`, run in the
  background, after QC, the base-lane hold, the local run and the stale check
  have all passed. In a private repo on the free plan, GitHub enforces no check,
  so this line is the enforcement.
- **No CI, no change:** a repo without `.github/workflows/gate.yml` keeps the
  local run as the proof of the suite.

**Limits accepted.** The hold covers the `**App tests:**` line (once the
operator amends ADR 0005), not every file the command runs: `npm test` reads
`package.json`, a config and every test file. So test paths and the files the
`**App tests:**` command runs never go in `LANE_LIGHT`, and the adversary pass
is where a loosened test is caught.

**Rejected.** Moving the acceptance commands into CI, or green CI as the verdict:
green CI is not a verdict (pstack), so QC and the adversary stay the verdict. A
`macos-latest` CI job instead of the local run: 10x minutes on a private repo.
Accepting the macOS gap: the gap has occurred once.

**Measurement and revert.** Arm A is the golden tag `golden-main-1.8.1-2026-11-14`
and the transcript numbers above. Arm B is the next 3 real cozystudio tickets.
Revert if, on 2 of 3, handoff → ready-to-merge is longer than arm A's median, a
suite run is in the developer's foreground, or a merge lands on a pending or red
`gate` (#123).
