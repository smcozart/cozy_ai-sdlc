# {{NAME}}

> **Start here:** read `STATUS.md` first — it is the live board; the open
> issues it mirrors are the live frontier. Then `CONTEXT.md` for the
> vocabulary, and this file for the contracts.

This repo runs the six-stage loop of the `engineering-workflow` plugin
(Plan → Design → Build → Test → Deploy → Maintain). The loop lives in the
plugin's `engineering-workflow` skill; this repo's merge policy is
`docs/engineering-workflow.md` Deploy.

**Base branch:** `{{BASE}}`

**Worker kind:** `claude`

## Issue tracker

GitHub Issues in this repo, through the `gh` CLI. Conventions, blocking
edges and the `ready-for-agent` contract: `docs/agents/issue-tracker.md`.

## Triage labels

The five triage roles, string for string: `needs-triage`, `needs-info`,
`ready-for-agent`, `ready-for-human`, `wontfix` (`docs/agents/triage-labels.md`).
Two more labels: `ticket` (an issue that is one unit of Build) and
`flagged-risk` (merges only after a human checkoff).

## Domain docs

`CONTEXT.md` at the repo root is the vocabulary. Decisions are ADRs in
`docs/adr/NNNN-slug.md`. Work-item intents and specs are in
`intent/<issue-number>-<slug>/` (start from `intent/TEMPLATE.md` and
`intent/TEMPLATE-spec.md`).

## Build read order

1. `gh issue view <n> --comments` — the ticket.
2. Its spec and intent: `intent/<n>-<slug>/` (or the parent design issue's folder).
3. Every ADR that touches the area.
4. `CONTEXT.md`.
5. Only then the code.

A ticket with a missing spec or link goes back to Design.

## Commands

- The **Base branch:** line above names the branch tickets start from and PR
  into (default main when the line is absent). The lane PARTIAL check measures
  a range against it (env `LANE_TARGET` overrides it).
- The **Worker kind:** line above is the agent kind for herdr worker panes
  (default claude when the line is absent).
- `tests/validate.sh [<range>]` — the Test gate. Healthy shape: one
  `ok: <name>` line per check below, then `N ok, 0 failed`, exit 0. Pass the
  ticket's range at close: `origin/{{BASE}}..HEAD`. Paste the run in the closing
  comment.
- `tests/validate.sh --witness` — proves each check fails on its bad case;
  exit 0 only when every witness gives the expected result.
- `tests/validate.sh --lane [<range>]` — classifies the diff's review lane
  (T0 trivial / T1 light / T2 heavy) from the files it touches. Exit 0 when a
  lane is printed, 2 when the range is empty or invalid. Escalate a lane,
  never lower it.
- `tests/validate.sh --list` — prints the check names:
  `shape`, `intent-layout`, `adr-numbering`, `app-tests`.
- App tests: when the stack ADR lands, add a line that starts with
  `**App tests:**` and names the command in backticks; the `app-tests` check
  runs it.
