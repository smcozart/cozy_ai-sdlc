# {{NAME}}

> **Start here:** say "catch me up" (`cmu`) for the live picture; the open
> issues are the live frontier, and `STATUS.md` is the review log. Then `CONTEXT.md` for the
> vocabulary, and this file for the contracts.

This repo runs the six-stage loop of the `ai-sdlc` plugin
(Plan → Design → Build → Test → Deploy → Maintain). The loop lives in the
plugin's skills (`intent-conversation`, `dispatch`, `cmu`); this repo's merge policy is
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
`flagged-risk` (marks a PR at `flagged: yes`; a human merges it).

## Domain docs

`CONTEXT.md` at the repo root is the vocabulary. Decisions are ADRs in
`docs/adr/NNNN-slug.md`. Work-item intents are in
`intent/<issue-number>-<slug>/intent.md` (start from `intent/TEMPLATE.md`);
there is no `spec.md`.

## Build read order

1. `gh issue view <n> --comments` — the ticket.
2. Its intent: `intent/<n>-<slug>/intent.md` (or the parent design issue's folder).
3. Every ADR that touches the area.
4. `CONTEXT.md`.
5. Only then the code.

A ticket with a missing intent or link goes back to Design.

## Commands

- The **Base branch:** line above names the branch tickets start from and PR
  into (default main when the line is absent). The lane PARTIAL check measures
  a range against it (env `LANE_TARGET` overrides it).
- The **Worker kind:** line above is the agent kind for herdr worker panes
  (default claude when the line is absent).
- `tests/validate.sh [--fast|--deadline <seconds>] [<range> [<pr-body-file>]]`
  — the Test gate. Healthy shape: one `ok: <name>` line per check below,
  then `N ok, 0 failed`, exit 0. Pass the ticket's range at close:
  `origin/{{BASE}}..HEAD`. Paste the run in the closing comment.
  - `tests/validate.sh --fast` runs every check but `app-tests`, which
    prints `deferred: app-tests — CI gate is the proof`.
  - `tests/validate.sh --deadline <s>` fails `app-tests` at `<s>` seconds
    and kills its whole process group. CI passes neither flag.
- `tests/validate.sh --witness` — proves each check fails on its bad case;
  exit 0 only when every witness gives the expected result.
- `tests/validate.sh --lane [<range>]` — prints the `range:` line and
  `flagged: yes|no` — yes when the range touches the merge hold list
  (`tests/validate.sh`, `.github/workflows/**`, `.githooks/**`), so a human
  merges. There is one review lane: every PR gets one adversary pass. Exit 0
  when the lines are printed, 2 when the range is empty or invalid.
  A PARTIAL range is not valid for a close.
- `tests/validate.sh --list` — prints the check names:
  `shape`, `intent-layout`, `adr-numbering`, `app-tests`, and `pr-adr-line`
  (fails a PR body with no `ADR:` line; CI passes the body file, a local run
  with none prints `skipped:`).
- App tests: when the stack ADR lands, add a line that starts with
  `**App tests:**` and names the command in backticks; the `app-tests` check
  runs it. The ticket range (`origin/{{BASE}}..HEAD`, from the merge-base)
  skips them when it and the working tree touch only records: `RECORDS_ONLY`
  in `tests/validate.sh` (`intent/`, `handoffs/`, `STATUS.md`); widen it to
  add a path, or set `RECORDS_ONLY=''` when a test reads records.
