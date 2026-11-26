# CozyHarness

> **Start here:** say "catch me up" (`cmu`) for the live picture; the open
> issues are the live frontier, and `STATUS.md` is the review log. Then `CONTEXT.md` for the
> vocabulary, this file for the contracts, and `docs/training/onboarding-runbook.md`
> for standing up a machine.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed via `gh` CLI; the `gh` commands and blocking edges are in `docs/agents/issue-tracker.md`. The `ready-for-agent` label is in `docs/agents/triage-labels.md`; its contract (blockers resolved + acceptance criteria defined) is in `docs/engineering-workflow.md` (Non-negotiables).

### Triage labels

The five canonical triage-role labels, string-for-string (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at repo root (created lazily), ADRs in `docs/adr/`. See `docs/agents/domain.md`.

### Spec & ticket overrides

Canonical rule lives in `docs/engineering-workflow.md` (stage table); this section is a pointer to it so the two can't silently diverge.

Overrides to the vendored skills: there is no `spec.md` and no `/to-spec` step — the work-item intent is the design record, and the issue body stays a brief that links to it (ADR 0008). `/to-tickets` does NOT apply `ready-for-agent`; the approval gate comes first.

## Engineering workflow

The standard process (planning → tickets → triage → implement → review → ADRs) is documented in `docs/engineering-workflow.md`. Read it before running any engineering skill. It is tool-agnostic: the same pipeline applies under pi, Claude Code, or any agent that can read this repo and run `gh`.

**Base branch:** `main`

## Commands

- The **Base branch:** line above names the branch tickets start from and PR into (default main when the line is absent). The lane PARTIAL check measures a range against it (env `LANE_TARGET` overrides it); it fails closed: a line that names no branch, a base that resolves to no ref, or a range with no common history prints PARTIAL.
- `tests/validate.sh [<range>]` — the Test gate. Healthy shape: one `ok: <name>` line per check below, then `N ok, 0 failed`, exit 0. Pass the ticket's range at close (e.g. `origin/main..HEAD`). Paste the run in the closing comment.
- `tests/validate.sh --witness` — replays every check's fail-first witness; exit 0 only if every bad sha / mutation fails and every good sha passes.
- `tests/validate.sh --lane [<range>]` — prints the `range:` line (resolved shas) and `flagged: yes|no` — yes when the range touches the merge hold list — the files that check other files; the list is `LANE_HOLD` in `tests/validate.sh` (ADR 0005) — so a human merges. There is one review lane: every PR gets one adversary pass (ADR 0008). The default gate run prints the same lines as a trailer over its range. A classifier, not a check name: exit 0 when the lines are printed, 2 when the range is empty or invalid (fix the range). Paste both lines beside the gate run at close; a PARTIAL range is not valid for a close.
- `tests/validate.sh --list` — prints the check names, which must equal this list (verified by the agents-commands check):
  - static: `intent-layout`, `adr-numbering`, `adr-refs`, `skill-frontmatter`, `skill-links`, `template-gate-parity`, `agents-commands`

## Pi configuration

Project agents, extensions, and prompts live under `.pi/`. The context footer shows the current repository, model, branch, and live context usage. The project subagent extension is available for scout, planner, reviewer, worker, and adversary work; use `agentScope: "project"` when dispatching it.
