# Intent: fix four skill-text defects found by the 1.7.0 simulation

**Issue:** #142 · **Status:** approved · **Type:** system-change

**Touches:** `["plugin/skills/dispatch/SKILL.md", "plugin/skills/herdr-orchestrator/SKILL.md", "plugin/skills/intent-conversation/SKILL.md", "intent/TEMPLATE.md", "plugin/templates/new-project/files/intent/TEMPLATE.md"]`

Sean, 2026-10-18, after the sandbox simulation and cozy-view's trace report: "1" (fix D1–D4 in one ticket, release 1.7.1). Evidence is on #142.

## Problem

See #142 for D1–D4 and the sandbox evidence.

## Desired outcome and scope

- **D1, stale check.**
  - `dispatch` Move 5: replace "If the branch is stale, …" with a concrete check. On every QC head, and again right before the merge, run `git fetch origin && git merge-base --is-ancestor origin/<base> HEAD`. A non-zero exit means stale: the worker updates the branch (the brief's merge-or-rebase rule) and the proof reruns.
  - `herdr-orchestrator` QC (step 4): add the same check, in one sentence, before the merge command.
- **D2, merge order.**
  - `dispatch` Move 5: the merge comes after the worktree is removed. First Move 6's checks (clean, pushed, HEAD equals the PR head). Then `git worktree remove <path>`. Then `gh pr merge --squash --delete-branch --match-head-commit …`. Then `git branch -D` if the local branch remains.
  - Move 6 keeps the session-close and app-workspace rules. It no longer removes a worktree that the merge step already removed.
  - `herdr-orchestrator` uses full clones, not worktrees, so D2 does not apply there. Do not change its merge order.
- **D3, intent status.** Remove `**Status:**` from both intent templates, and the "`**Status:** draft`" part from `intent-conversation` Move 2. The approval record is the issue comment (Move 3), as before. Leave the `SYSTEM-INTENT.md` status line (Move 1) as it is. Leave existing intent files as they are; they are history.
- **D4, type definitions.** In both intent templates, define each type in one line under the header line:
  - `feature`: new behavior a user of the app can see or use;
  - `bug`: behavior that differs from what an intent or spec already states;
  - `system-change`: a change to how the repo is built, checked, reviewed or released (gate, CI, hooks, workflow, skills, ADR policy), not to the app's behavior.

  Add one sentence in `intent-conversation` Move 2: when a request fits none of them, or fits two, choose `system-change`. It keeps the early records review.

## Non-goals

- Any change to `tests/validate.sh` or to the consumer gate.
- The waste items in cozy-view's report: the guardrail probe sub-agent, the duplicate app-test runs, and the `t<n>` vs lane-name clash. They wait in the #121 ledger.

## Acceptance criteria

- `git grep -n 'merge-base --is-ancestor' -- plugin/skills/dispatch plugin/skills/herdr-orchestrator` shows the check in both skills.
- In `dispatch`, `git worktree remove` comes before `--delete-branch`. Paste the line numbers.
- `git grep -n 'Status:\*\* draft' -- plugin/skills intent/TEMPLATE.md plugin/templates/new-project/files/intent/TEMPLATE.md` finds nothing.
- Both templates are byte-identical (`cmp`) and carry the 3 type definitions.
- `bash tests/validate.sh --witness` passes, and `bash tests/validate.sh origin/main..HEAD <body>` exits 0 with `flagged: no`. The PR touches no hold-list file, so it merges on green after QC.

## System-intent alignment

Closes the gaps that the simulation proved real, using the evidence rule (#119). No new feature.
