# CozyHarness

> **Start here:** read `STATUS.md` first — it is the single live board; the
> open issues it mirrors are the live frontier. Then `CONTEXT.md` for the
> vocabulary, this file for the contracts, and `docs/training/onboarding-runbook.md`
> for standing up a machine.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed via `gh` CLI; blocking edges and the `ready-for-agent` contract are defined there. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage-role labels, string-for-string (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at repo root (created lazily), ADRs in `docs/adr/`. See `docs/agents/domain.md`.

### Spec & ticket overrides

Canonical rule lives in `docs/engineering-workflow.md` (stage table); this section is a pointer to it so the two can't silently diverge.

Overrides to the vendored skill: `/to-spec` writes the spec to `intent/<n>-<slug>/spec.md`, NOT into the issue body — the issue body stays a brief (ADR 0001) — and does NOT apply `ready-for-agent` at spec time; the approval gate comes first.

## Engineering workflow

The standard process (planning → tickets → triage → implement → review → ADRs) is documented in `docs/engineering-workflow.md`. Read it before running any engineering skill. It is tool-agnostic: the same pipeline applies under pi, Claude Code, or any agent that can read this repo and run `gh`.

## Commands

- `tests/validate.sh [<range> [<pr-body-file>]]` — the Test gate. Healthy shape: one `ok: <name>` line per check below, then `N ok, 0 failed`, exit 0. Pass the ticket's range at close (e.g. `origin/main..HEAD`). Paste the run in the closing comment.
- `tests/validate.sh --witness` — replays every check's fail-first witness; exit 0 only if every bad sha / mutation fails and every good sha passes.
- `tests/validate.sh --lane [<range>]` — classifies the diff's review lane (T0 trivial / T1 light / T2 heavy) as an allow-list over files, paths and line count (ADR 0003), then prints `flagged: yes|no` — yes when the range touches the merge hold list (`tests/validate.sh`, `.github/workflows/**`, `.githooks/**`; ADR 0005), so a human merges. The default gate run prints the same lines as a trailer over its range. A classifier, not a check name: exit 0 when a lane is printed, 2 when the range is empty or invalid (then there is no lane — fix the range). Paste both lines beside the gate run at close; a PARTIAL range is not valid for a close; escalate, never lower.
- `tests/validate.sh --list` — prints the check names, which must equal this list (verified by the agents-commands check):
  - static: `sync-rule`, `stage-parity`, `intent-layout`, `adr-numbering`, `adr-refs`, `hooks-json`, `skill-frontmatter`, `skill-copies`, `agents-commands`
  - regression (#8 corpus): `t1-trust-wording`, `t1-log-clobber`, `t1-spawn-session`, `t3-label-drift`, `t3-precedence`
  - PR body (ADR 0005): `pr-adr-line` — fails a body with no `ADR:` line; CI passes the body file, a local run with none prints `skipped:`

## Pi configuration

Project agents, extensions, and prompts live under `.pi/`. The context footer shows the current repository, model, branch, and live context usage. The project subagent extension is available for scout, planner, reviewer, worker, and adversary work; use `agentScope: "project"` when dispatching it.
