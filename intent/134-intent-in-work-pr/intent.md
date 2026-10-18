# Intent: small tickets carry their intent in the work PR

**Issue:** #134 · **Status:** approved · **Type:** system-change

**Touches:** `["plugin/skills/intent-conversation/SKILL.md", "plugin/skills/dispatch/SKILL.md", "plugin/skills/herdr-orchestrator/SKILL.md", "plugin/skills/engineering-workflow/SKILL.md", "docs/engineering-workflow.md", "README.md"]`

After #132 lands, `.claude/` and `.agents/` are symlinks, so no copies change. `README.md` is listed because the `sync-rule` check moves the workflow document, the `engineering-workflow` skill and `README.md` together.

From the harness review, Sean, 2026-10-18 (item 3, "work in the risks you've spotted"). QC of the records PR (#136) found that a lane hint does not exist at filing, so the flow keys on `**Type:**` instead.

## Problem

Every ticket gets a records PR for its intent before its work PR. `intent-conversation` Move 3 refuses "go" while a records PR names the issue, and `dispatch` Move 1 refuses an intent that is not on the base branch. For a small ticket this doubles the PRs, the CI waits and the merges (#123: 2.4 PRs per ticket).

## Desired outcome

The flow is chosen by the intent's existing `**Type:**` field, not by a lane hint. `intent-conversation` says "Do not name a lane" (SKILL.md near 115), and that rule stays.

- **`feature` or `bug`.** At filing (Move 2), the session:
  1. creates `t<n>-<slug>` from `origin/<base>`, in a worktree under `.factory/worktrees/t<n>-<slug>`, never in the developer's checkout;
  2. commits `intent/<n>-<slug>/intent.md` there;
  3. pushes the branch, with no PR.

  A decision for that ticket (Move 2b) is committed on the same branch. On "go" (Move 3): the approval comment, then the label. The worker continues on that branch. Intent and code land in one PR.
- **`system-change`.** No change: a separate records PR, QC, merge, then "go". All the intents that review caught HIGH defects in (#126, #129) were system changes.
- **Decisions without a ticket** (Move 2b): no change. They keep the records PR.

This replaces the "T0 or T1 only" limit from the review. It uses a field that every intent already has, so no lane hint has to be added back.

## Risk handling (intent defects found late)

The risk: a defect in a feature or bug intent is found only after the code is built. Two rules limit it:
- QC on the combined PR reviews the intent first, and the lane's adversary pass covers the whole diff, intent included.
- If the review finds a HIGH defect in the intent, the worker fixes the intent first, then the code, in the same PR.

## Scope

- `intent-conversation`:
  - Move 2: for `feature` or `bug`, the intent goes on the ticket branch as above. The reply names the branch.
  - Move 2b: a ticket-bound decision is committed on that ticket's branch when the branch exists.
  - Move 3: the precondition is "the intent is on `<base>`, or on `origin/t<n>-<slug>`". "No open records PR names this issue" still holds for `system-change`.
- `dispatch`:
  - Move 1: an intent counts when it is on `<base>` or committed on `origin/t<n>-<slug>`.
  - Move 2: when `origin/t<n>-<slug>` exists, the reserved base SHA is its merge-base with `origin/<base>`.
  - Move 3: when that branch exists, the worktree checks it out (`git worktree add <path> t<n>-<slug>`). It does not create it with `-b`.
  - Worker brief (near SKILL.md 216-221): if `origin/t<n>-<slug>` exists, `git switch t<n>-<slug>` and continue. Never rename the branch, and never create it from `<sha>` in that case.
- `herdr-orchestrator`: its worker template already allows continuing on an existing branch. Add the same Move 1 sentence about where the intent may be.
- `engineering-workflow`: the skill, the document and `README.md`, with one sentence each that names the two flows (the `sync-rule` check moves them together).

## Non-goals

- Changing lanes or the T2 flow.
- Any gate change.

## Acceptance criteria

- Each changed skill states the rule in one place, and the documents point to it. `git grep -n 'origin/t<n>-<slug>'` output is pasted on the PR.
- A dry run in a scratch clone: write a `feature` intent on `t999-x`, push it to a local bare remote, then follow the dispatch Move 3 and worker-brief steps. The worker's branch keeps the intent commit, and a normal push succeeds.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0.
- Success check, after release 1.7.0: the next `feature` or `bug` ticket, in any repo, lands its intent and its code in one PR. Record it on #134 when it happens. It does not block the merge.

## System-intent alignment

Fewer PRs per small ticket, with the review of the intent kept where it has paid off.
