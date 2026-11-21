# The Harness

Read `AGENTS.md` — it is the single source of the workflow, commands,
and contracts for this repo. This file is only the pointer.

- Workflow: `docs/engineering-workflow.md` (six-stage loop)
- Review policy: `REVIEW.md` · Vocabulary: `CONTEXT.md`
- Skills: `.claude/skills/` (symlinks to `plugin/skills/`)
- Proof gate: `tests/validate.sh [<range>]` · `--witness` for fail-first
- Prerequisite: `./bootstrap.sh` installs the tools `.claude/settings.json`
  names, Matt Pocock skills included (project scope, cozysuite catalog) — `/to-spec`, `/triage`, `/to-tickets` are not
  repo files.

## Claude Code only: Code Mode for the orchestrator (#184)

This is a Claude Code setting, not part of the workflow. pi, Copilot and other
hosts ignore it, and no skill, gate check or `AGENTS.md` rule depends on it.

- Only the orchestrator pane may run Code Mode (experimental). Set it in that
  pane's shell before starting: `export CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1`.
  Never set it in `~/.claude/settings.json`: that turns it on for workers too.
- Keep the user-level rule `permissions.ask: ["Bash(rm -rf:*)"]`. In auto mode
  Code Mode does not check paths that the code computes, and the ask rule makes
  each retire delete ask the developer.
- To turn it off, start the pane without the variable. The loop is unchanged.
