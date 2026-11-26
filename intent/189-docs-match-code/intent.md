# Intent: Live docs state only what the code does

**Issue:** #189 · **Type:** bug

**Touches:** `["README.md", "CLAUDE.md", "AGENTS.md", "CONTRIBUTING.md", "docs/engineering-workflow.md", "docs/training/onboarding-runbook.md", "docs/agents/issue-tracker.md", "plugin/README.md", "plugin/skills/cmu/SKILL.md", "plugin/templates/new-project/files/STATUS.md", "intent/189-docs-match-code/**"]`

## Problem

A read-only audit of every live doc against main 090c916 found statements the code does not back. An agent or a person who follows them does the wrong thing. The worst case is the onboarding runbook's `cp` recipe: it produces a project with no gate, and its bootstrap fails. The 15 items with file:line references are listed on #189.

## Desired outcome

- Each of the 15 statements on #189 is corrected to match the code, or removed when nothing backs it.
- Where a doc restates a fact that the code already prints, it points to the source instead of copying it. Examples: a count of checks or `ok:` lines, a list of checks, a protection ruleset. That way the next code change cannot make the doc false.
- No rule changes. Where docs disagree about behavior that the code does not settle, the item stays out of this PR (two such items are held on #121).

## Scope

- The 15 items on #189, in the files listed in Touches.
- For item 6 (pi and `.agents/skills/`), first establish the truth from evidence:
  - what pi's loader reads: `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/resource-loader.js`, and pi's skill loading if it is separate;
  - what `.gitignore` keeps;
  - what `bootstrap.sh` restores.

  Then make all three docs say that one thing.

## Non-goals

- dispatch's non-herdr guardrail sentence, and cmu's handoff anchor: rule decisions held on #121 under the freeze.
- No gate, workflow, skill-behavior or template-gate changes.
- No historical records: `intent/<n>-*`, `handoffs/`, `docs/verify/`, ADR history lines.
- No `claude-harness` branch, no release.

## Acceptance criteria

- `bash tests/validate.sh origin/main..HEAD` exits 0 with `flagged: no`.
- Each of the 15 items is fixed. The PR body lists each item with its new text or "removed", plus the evidence it now matches.
- `git grep -nE '14 ok|copilot-instructions|\.factory/wt/|docs/journal|/build\b' -- ':!intent/' ':!handoffs/' ':!docs/verify/' ':!docs/adr/'` prints nothing.
- `git grep -nE -- '--body "' docs/agents/` prints nothing.

## System-intent alignment

Accuracy: the contracts make judgement auditable only if they are true. Every change here is a correction, and nothing is added beyond a pointer.
