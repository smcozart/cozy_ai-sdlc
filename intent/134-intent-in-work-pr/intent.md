# Intent: small tickets carry their intent in the work PR

**Issue:** #134 · **Status:** approved · **Type:** system-change

**Touches:** `["plugin/skills/intent-conversation/SKILL.md", "plugin/skills/dispatch/SKILL.md", "plugin/skills/herdr-orchestrator/SKILL.md", "plugin/skills/engineering-workflow/SKILL.md", "docs/engineering-workflow.md", "README.md"]`

After #132 lands, `.claude/` and `.agents/` are symlinks, so no copies change. `README.md` is listed because the `sync-rule` check moves the workflow document, the `engineering-workflow` skill and `README.md` together.

From the harness review, Sean, 2026-10-18 (item 3, "work in the risks you've spotted").

## Problem

Every ticket gets a records PR for its intent before its work PR. `intent-conversation` Move 3 refuses "go" while a records PR names the issue, and `dispatch` Move 1 refuses an intent that is not on the base branch. For a small ticket this doubles the PRs, the CI waits and the merges (#123: 2.4 PRs per ticket).

## Desired outcome

- **T0 or T1 lane hint.** The lane hint is the "Likely T1 light" or "T2 heavy" line from `intent-conversation` Move 2. On "go", the orchestrator:
  1. posts the approval comment;
  2. applies the label;
  3. creates `t<n>-<slug>` from `origin/<base>`;
  4. commits `intent/<n>-<slug>/intent.md` as the first commit, and pushes it.

  The worker continues on that branch, as the herdr-orchestrator worker template already allows ("If `t<n>-<slug>` … already exists, check it out and continue"). Intent and code land in one PR.
- **T2 lane hint.** No change: a separate records PR, QC, merge, then "go".
- **Decisions without a ticket** (`intent-conversation` Move 2b): no change. They keep the records PR.

## Risk handling (intent defects found late)

The risk: a defect in the intent is found only after the code is built. Today, review of the intent before the build caught HIGH defects (#126, #129). Three rules limit it:
- The combined flow applies only to a T0 or T1 hint, where the intent is small.
- QC on the combined PR reviews the intent first, and the adversary pass covers the whole diff, intent included.
- If the computed lane at close is T2, the full T2 adversary runs, intent included. If it finds a HIGH defect in the intent, the worker fixes the intent first, then the code, in the same PR.

## Scope

- `intent-conversation`:
  - Move 2: the lane hint chooses the flow, and the reply says which flow.
  - Move 3: "go" for a T0 or T1 hint creates the ticket branch with the intent commit, not a records PR.
- `dispatch` Move 1, and the matching text in `herdr-orchestrator`: an intent counts when it is on the base branch or committed on `t<n>-<slug>`.
- `engineering-workflow`: the skill, the document and `README.md`, each with one sentence that names the two flows.

## Non-goals

- Changing lanes or the T2 flow.
- Any gate change.

## Acceptance criteria

- Each changed skill states the rule in one place, and the documents point to it. `grep -n` output for "T0 or T1" or "lane hint" is pasted on the PR.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0.
- Success check, after release 1.7.0: the next ticket with a T0 or T1 hint, in any repo, lands its intent and its code in one PR. Record it on #134 when it happens. It does not block the merge.

## System-intent alignment

Fewer PRs per small ticket, with the review of the intent kept where it has paid off.
