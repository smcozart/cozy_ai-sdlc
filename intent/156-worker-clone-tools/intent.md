# Intent: a dispatch worker's clone has the repo's tools installed before the worker starts

**Issue:** #156 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/skills/dispatch/SKILL.md", "plugin/.claude-plugin/plugin.json"]`

## Problem

Tools install per project only (smcozart/cozysuite#1). Claude Code records
each install against one folder path; a committed `.claude/settings.json`
names the tools but installs nothing. `dispatch` starts each herdr worker in a
fresh clone at a new path, so the worker loads none of the repo's tools: no
guard hooks, no ponytail, no mattpocock-skills. The guardrail probe then runs
instead of being denied (`plugin/skills/dispatch/SKILL.md:96-104`).

Evidence, 2026-10-25: the smcozart/cozy_view#82 worker's probe was refused by
the OS, not by a hook. A fresh clone of this repo: 6 tools named, 0 installs
recorded, 0 plugin skills loaded, and `PATH=/usr/bin ls -d /tmp` ran.

## Desired outcome

Before a worker starts, its clone has every `enabledPlugins` entry of its
committed settings installed at project scope, so the probe is denied by the
repo's own hooks. Retiring the worker removes those installs.

## Scope

- `dispatch` Move 3: the install step for the herdr row, and the same for the
  worktree rows (each new worktree is also a new path).
- `dispatch` Move 6: remove the worker's installs before its clone or worktree
  is deleted.
- `plugin/.claude-plugin/plugin.json`: raise the version.

## Non-goals

- The tools a repo chooses (`/cozysuite:setup`), and the catalog.
- `bootstrap.sh` (it already installs from the committed settings, #154).

## Acceptance criteria

- On a fresh clone of this repo, following the new Move 3 step: the plugin
  skills of every named tool load (`claude -p` skill list), and
  `PATH=/usr/bin ls -d /tmp` is blocked by a hook.
- Following the new Move 6 step: `claude plugin list --json` has no entry
  whose `projectPath` is the removed clone.
- `bash tests/validate.sh origin/main..HEAD` exits 0.

## System-intent alignment

Unattended workers run under the same guardrails as the developer's own
checkout.
