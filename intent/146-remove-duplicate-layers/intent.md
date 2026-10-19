# Intent: remove the duplicate layers — herdr folds into dispatch, the engineering-workflow skill and the two advisory hooks go

**Issue:** #146 · **Type:** system-change

**Touches:** `["plugin/skills/dispatch/SKILL.md", "plugin/skills/herdr-orchestrator/**", "plugin/skills/engineering-workflow/**", ".claude/skills/herdr-orchestrator", ".claude/skills/engineering-workflow", ".agents/skills/herdr-orchestrator", "plugin/hooks/hooks.json", "tests/validate.sh", ".githooks/pre-commit", ".gitignore", "plugin/templates/new-project/files/.gitignore", "plugin/templates/new-project/files/AGENTS.md", "plugin/templates/new-project/files/docs/engineering-workflow.md", "plugin/skills/new-project/SKILL.md", "plugin/skills/cmu/SKILL.md", "plugin/README.md", "README.md", "CONTRIBUTING.md", "AGENTS.md", "REVIEW.md", "docs/engineering-workflow.md", ".claude/verify-host.md", "docs/adr/**"]`

Sean, 2026-10-18: "1, then freeze after 1.8.0"; on herdr: "1, herdr panes count as supervised — I like this being the default with the backup being primary harness with sub-agent orchestration". Covers #122.

## Problem

See #146. `herdr-orchestrator` and `dispatch` both orchestrate workers, QC and merge. The `engineering-workflow` skill repeats the workflow doc. Two advisory hooks enforce nothing.

## Desired outcome

**1. herdr becomes the first host row in `dispatch`.**
- Move 3's detection order becomes:
  1. **herdr**, when `HERDR_PANE_ID` is set and `herdr` is on `PATH`;
  2. the harness's own session-creation tool;
  3. a sub-agent with worktree isolation;
  4. a headless child session in a worktree.
- The herdr row carries the launch recipe from `herdr-orchestrator`:
  - one full clone per ticket under `~/.factory/<repo>/workers/w<n>`, never a worktree;
  - `herdr tab create --cwd …`, `herdr agent start <name> --kind claude --pane <id>`, `herdr agent prompt`;
  - watch with `herdr agent list` / `read` / `wait`;
  - the worker pings back with `herdr agent prompt <ORCH_PANE_ID> "HANDOFF: …"`;
  - retire: `herdr tab close`, then remove the clone.
- **Guardrail:** a worker in a herdr pane counts as supervised. Each pane is visible, and the developer can read and step into it. The worker runs in Claude's normal permission mode, never bypass. The probe still runs, and its result is reported. The rule "runs serially in the supervised parent" still applies to every other host when no guardrail denies the probe.
- **Clone-retire guard (keep it, word for word):** a clone is removed only if:
  - `git -C <clone> status --porcelain` is empty;
  - `git -C <clone> stash list` is empty;
  - `git -C <clone> log --oneline --branches --not --remotes HEAD` is empty;
  - the PR is `MERGED`;
  - `HEAD` equals `headRefOid`.

  Otherwise the clone is kept and named. It goes in `dispatch` Move 6 for the clone host.
- The herdr folder-trust prompt (#106) is accepted for a fresh clone of the repo itself: one sentence.
- Delete `plugin/skills/herdr-orchestrator/`, its `.claude` and `.agents` symlinks, and its `.gitignore` exception. In `cmu`, the one sentence that names `herdr-orchestrator` changes to name `dispatch`.

**2. Delete the `engineering-workflow` skill.**
- Delete `plugin/skills/engineering-workflow/` and its `.claude` symlink.
- `sync-rule` and `.githooks/pre-commit`: a change to `docs/engineering-workflow.md` requires `README.md` in the same commit or range. That is the pair, with no skill.
- `stage-parity`: compare `docs/engineering-workflow.md` and `README.md` only.
- Update every reference that names the skill as a thing to load (`new-project`, template `AGENTS.md`, template workflow doc, `plugin/README.md`, `CONTRIBUTING.md`, `README.md`). The `<!-- engineering-workflow:start -->` markers and the `docs/engineering-workflow.md` name are contracts and stay. History (ADRs, `intent/`, `handoffs/`) stays as written.

**3. Delete the two advisory hooks.**
- Delete `plugin/hooks/hooks.json`, the `hooks-json` check, its witness rows and its `AGENTS.md ## Commands` line.
- `.githooks/` (pre-commit, pre-push) stays. Those hooks enforce.
- A new ADR (the next free number): the advisory reminder and the PostToolUse advisory from #21 are removed. They enforced nothing and printed on every prompt and Bash call. Enforcement stays in the gate and in `.githooks/`.

**4. Gate updates.**
- `FO` points at `plugin/skills/dispatch/SKILL.md`, so `herdr-retire` checks the guard sentence there. Its mutation rows stay.
- `SKILL_LINKS` drops the two deleted skills.
- `SK`, and every check and witness that reads it, change as above.
- Re-check the sync witnesses pinned to old commits (`a6519a9`, `571afe4`). Each one must still test what its label says, or it is removed with a reason.

## Non-goals

- `STATUS.md` (#147).
- Any change to `dispatch`'s behavior other than the host order, the herdr row and the guard move.
- The consumer gate template. Only the template's text names the skill.

## Acceptance criteria

- `bash tests/validate.sh --witness` passes. Paste the witness count before and after, and give the reason for each removed row.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0, `flagged: yes`. A named human merges.
- `git grep -nE 'herdr-orchestrator|skills/engineering-workflow|hooks\.json' -- . ':!intent' ':!handoffs' ':!docs/adr'` finds only the new ADR and `dispatch`'s own history sentence, if any. Paste the output.
- In `dispatch`, the herdr row is first in Move 3's order and carries the guard sentence. `herdr-retire` passes on it, and its 3 mutation rows fail.
- A herdr dry run in a scratch clone: following the new `dispatch` text, a herdr worker pane starts, the guardrail line is reported as "herdr pane: supervised", and the pane is retired behind the guard. Paste the commands and output. If herdr cannot run in the worker's environment, say so and paste the text review instead.
- `claude -p "List the names of the project skills you can see"` in the clone shows `cmu`, `dispatch`, `intent-conversation` and `new-project`, and neither deleted skill.

## System-intent alignment

Each part of the plugin solves one problem, and nothing that guards behavior is lost.
