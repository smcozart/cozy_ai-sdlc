# The Harness

Read `AGENTS.md` — it is the single source of the workflow, commands,
and contracts for this repo. This file is the pointer, plus one Claude Code
only setting at the end.

- Workflow: `docs/engineering-workflow.md` (six-stage loop)
- Review policy: `REVIEW.md` · Vocabulary: `CONTEXT.md`
- Skills: `.claude/skills/` (symlinks to `plugin/skills/`)
- Proof gate: `tests/validate.sh [<range>]` · `--witness` for fail-first
- Prerequisite: `./bootstrap.sh` installs the tools `.claude/settings.json`
  names, Matt Pocock skills included (project scope, cozysuite catalog) — `/triage`, `/to-tickets` are not
  repo files.

## Claude Code only: Code Mode for the orchestrator (#184)

This is a Claude Code setting, not part of the workflow. Other hosts (pi,
Copilot) have no such setting, and no skill, gate check or `AGENTS.md` rule
depends on it. pi loads `AGENTS.md`, not this file.

- Only the herdr orchestrator pane may run Code Mode (experimental). Set it in
  that pane's shell before starting `claude`:
  `export CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1`, then confirm the first-run
  prompt. A herdr pane takes its environment from the herdr server, not from
  the orchestrator pane, so herdr workers stay off only while herdr itself was
  started without the variable. Whether sub-agents of the orchestrator run in
  Code Mode is not documented; treat it as possible. Never set the variable in
  `~/.claude/settings.json`: that turns it on for every session.
- Keep the user-level rule `permissions.ask: ["Bash(rm -rf:*)"]`. In auto mode
  the safety classifier reads each piece of code once and does not see paths
  that the code computes. Ask rules and `PreToolUse` hooks still run on each
  tool call inside the code, so the herdr retire's `rm -rf <clone>` asks the
  developer. The rule matches that command text only, not `git worktree
  remove` or other spellings of `rm`.
- To turn it off, start the pane without the variable. A session started in
  Code Mode resumes only with the variable set. The loop is unchanged.
