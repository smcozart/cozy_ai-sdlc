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
