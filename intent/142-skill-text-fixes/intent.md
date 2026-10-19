# Intent: fix four skill-text defects found by the 1.7.0 simulation

**Issue:** #142 · **Status:** approved · **Type:** system-change

**Touches:** `["plugin/skills/dispatch/SKILL.md", "plugin/skills/herdr-orchestrator/SKILL.md", "plugin/skills/intent-conversation/SKILL.md", "intent/TEMPLATE.md", "plugin/templates/new-project/files/intent/TEMPLATE.md", "intent/TEMPLATE-spec.md", "plugin/templates/new-project/files/intent/TEMPLATE-spec.md"]`

Sean, 2026-10-18, after the sandbox simulation and cozy-view's trace report: "1" (fix D1–D4 in one ticket, release 1.7.1). Evidence is on #142.

## Problem

See #142 for D1–D4 and the sandbox evidence.

## Desired outcome and scope

- **D1, stale check.** Check against the exact head QC ran on, before anything is removed: `git fetch origin && git merge-base --is-ancestor origin/<base> <the head SHA QC ran on>`. A non-zero exit means stale: the worker updates the branch (the brief's merge-or-rebase rule) and the proof reruns. A failed fetch also reads as stale, which is the safe direction.
  - `dispatch` Move 5: replace "If the branch is stale, …" with this check. Run it on every QC head, and again right before the merge.
  - `herdr-orchestrator` QC (step 4): the same check, in one sentence, before the merge command. Also: after `gh pr checkout`, `git rev-parse HEAD` must equal the PR's `headRefOid`.
- **D2, branch delete.** Keep the order (merge, then Move 6 retires the worktree), so a failed merge still leaves the worker its worktree, and the app-workspace and GitHub-click paths are unchanged.
  - `dispatch` Move 5: merge with `gh pr merge --squash --match-head-commit <sha> <pr>`, with no `--delete-branch`, then `git push origin --delete <branch>`.
  - Move 6 removes the worktree and the local branch as now.
  - Keep the text "and the gate run's `flagged:` line says `flagged: no`" word for word: `tests/validate.sh` (`dispatch-hold`, near line 233) checks it.
  - `herdr-orchestrator` uses full clones, so its `--delete-branch` works. Do not change it.
- **D3, intent status.** Remove `**Status:**` from both intent templates and both spec templates (`TEMPLATE-spec.md`), and the "`**Status:** draft`" part from `intent-conversation` Move 2. The approval record is the issue comment (Move 3), as before. Leave the `SYSTEM-INTENT.md` status line (Move 1) as it is. Leave existing intent files as they are; they are history.
- **D4, type definitions.** In both intent templates, define each type in one line under the header line:
  - `feature`: new behavior a user of the app can see or use;
  - `bug`: the app behaves differently from what an intent, a spec or the developer expects;
  - `system-change`: a change to how the repo is built, checked, reviewed or released (gate, CI, hooks, workflow, skills, ADR policy), not to the app's behavior.

  Add one sentence in `intent-conversation` Move 2: when unsure whether a request is a `system-change`, choose `system-change`. It keeps the early records review. A feature/bug tie needs no rule, because both take the same flow.

## Non-goals

- Any change to `tests/validate.sh` or to the consumer gate.
- The 1.7.1 version bump. It ships as its own version-only release PR (lane T1, #135), as 1.7.0 did (#141).
- The waste items in cozy-view's report: the guardrail probe sub-agent, the duplicate app-test runs, and the `t<n>` vs lane-name clash. They wait in the #121 ledger.

## Acceptance criteria

- `git grep -n 'merge-base --is-ancestor' -- plugin/skills/dispatch plugin/skills/herdr-orchestrator` shows the check in both skills.
- In `dispatch` Move 5, the merge command has no `--delete-branch`, and `git push origin --delete <branch>` follows it. `dispatch-hold` still passes.
- `git grep -n 'Status:\*\*' -- intent/TEMPLATE.md intent/TEMPLATE-spec.md plugin/templates/new-project/files/intent/` finds nothing, and `git grep -n 'Status:\*\* draft' -- plugin/skills` finds nothing.
- Each root template is byte-identical to its consumer copy (`cmp`), and both `TEMPLATE.md` copies carry the 3 type definitions.
- `bash tests/validate.sh --witness` passes, and `bash tests/validate.sh origin/main..HEAD <body>` exits 0 with `flagged: no`. The PR touches no hold-list file, so it merges on green after QC.

## System-intent alignment

Closes the gaps that the simulation proved real, using the evidence rule (#119). No new feature.
