# Intent: worker launches never stall on the Claude folder-trust prompt

**Issue:** #106 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/skills/dispatch/SKILL.md", "plugin/skills/factory-orchestrator/SKILL.md", ".claude/skills/dispatch/SKILL.md", ".claude/skills/factory-orchestrator/SKILL.md", "plugin/skills/new-project/SKILL.md", ".claude/skills/new-project/SKILL.md"]`

## Problem

On 2026-10-13 a dispatched worker for smcozart/cozy_observe#1 started in a new worktree under an untrusted repo. Claude Code showed the folder-trust prompt; the brief's Enter chose "No, exit", the session closed with no work, and nothing reported it. The developer: "Let's make sure we have a better method for handling this in the future so we don't hit stoppers on simple things like this."

## Desired outcome

- Trust is accepted once per repo, at its root, by the developer. Ticket worktrees live under `<repo>/.factory/worktrees/`, so they inherit it. Evidence, 2026-10-13: a new subfolder of trusted `cozyharness` (`.factory/trust-probe3`) opened Claude with no prompt.
- Before any brief is sent, the orchestrator reads the worker pane. A trust prompt on screen means: send nothing, press no key, end the turn on `Needs you: open the herdr tab "<label>" and choose "Yes, I trust this folder" — or trust <repo root> once — then say "trusted"`.
- `new-project` ends its hand-off with one line asking the developer to open Claude once at the new repo root and accept trust.

## Scope

- The pre-send pane check and the worktree location in `dispatch` and `factory-orchestrator`, in the plugin source and the `.claude/skills/` copies.
- The trust line in the `new-project` hand-off.

## Non-goals

- Accepting trust on the developer's behalf: no key presses on the prompt, no writes to `~/.claude.json`.
- Headless `-p` workers: trust is skipped there already (`factory-orchestrator`, "Headless trust").

## Acceptance criteria

- In a repo whose root is untrusted, a dispatch run stops before sending the brief and prints the `Needs you:` trust line; the worker pane still shows the prompt, untouched.
- In a repo whose root is trusted, a dispatch run to a new `.factory/worktrees/` worktree reaches the worker's guardrail probe with no developer action.
- `tests/validate.sh` passes on the range, and the plugin and `.claude/skills/` copies match.

## System-intent alignment

Keeps unattended dispatch unattended, and keeps trust a human decision.
