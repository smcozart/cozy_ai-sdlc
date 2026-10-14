# Intent: worker launches never stall on the Claude folder-trust prompt

**Issue:** #106 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/skills/dispatch/SKILL.md", "plugin/skills/herdr-orchestrator/SKILL.md", ".claude/skills/dispatch/SKILL.md", ".claude/skills/herdr-orchestrator/SKILL.md", "plugin/skills/new-project/SKILL.md", ".claude/skills/new-project/SKILL.md"]`

## Problem

On 2026-10-13 a dispatched worker for smcozart/cozy_observe#1 started in a new worktree under an untrusted repo. Claude Code showed the folder-trust prompt; the brief's Enter chose "No, exit", the session closed with no work, and nothing reported it. The developer: "Let's make sure we have a better method for handling this in the future so we don't hit stoppers on simple things like this."

The same run showed a second launch race: `herdr agent start` sent right after `herdr tab create` returned `agent_pane_busy` or no agent JSON. Waiting for the shell prompt (about 2 s) fixed it.

Claude records trust per git root (`~/.claude.json`). Measured 2026-10-13:
- A linked worktree under a trusted root opens with no prompt (`cozy_observe/.factory/worktrees/t2-raw-events-table`).
- A separate git repo inside a trusted folder still shows the prompt. So `herdr-orchestrator` worker clones under `~/.factory/<repo>/workers/w<n>` always prompt, and trusting `~/.factory` does not help. The orchestrator has answered that prompt by hand for every worker since #49; the skill does not say so.

## Desired outcome

- Every launch waits for the shell prompt before `herdr agent start`, and reads the pane before `herdr agent prompt`.
- `dispatch` (linked worktrees under `<repo>/.factory/`): trust is accepted once per repo, at its root, by the developer. A trust prompt on screen means: send nothing, press no key, end the turn on `Needs you: trust <repo root> once (open Claude there and choose "Yes, I trust this folder"), then say "trusted"`.
- `herdr-orchestrator` (full clones under `~/.factory/<repo>/workers/w<n>`): the orchestrator accepts the trust prompt only when all hold: the pane is one it just started, the folder is a clone it just made under `~/.factory/<repo>/workers/`, and the clone's `origin` URL equals the repo's own `origin`. Anything else gets the `Needs you:` line above, with no key pressed.
- `new-project` ends its hand-off with one line asking the developer to open Claude once at the new repo root and accept trust.

## Scope

- The launch wait, the pre-send pane check and the trust rule in `dispatch` and `herdr-orchestrator`, in the plugin source and the `.claude/skills/` copies.
- The trust line in the `new-project` hand-off.

## Non-goals

- Writes to `~/.claude.json`.
- Accepting trust for any folder outside the narrow `herdr-orchestrator` rule above.
- Headless `-p` workers: trust is skipped there already (`herdr-orchestrator`, "Headless trust").

## Acceptance criteria

- In a repo whose root is untrusted, a `dispatch` run stops before sending the brief and prints the `Needs you:` trust line; the worker pane still shows the prompt, untouched.
- In a repo whose root is trusted, a `dispatch` run to a new `.factory/worktrees/` worktree reaches the worker's guardrail probe with no developer action.
- A `herdr-orchestrator` run starts a worker in a new `~/.factory/<repo>/workers/w<n>` clone and reaches the guardrail probe with no developer action; the skill text names all three conditions of the trust rule.
- No launch in either skill shows `agent_pane_busy` from starting before the shell prompt.
- `tests/validate.sh` passes on the range, and the plugin and `.claude/skills/` copies match.

## System-intent alignment

Keeps unattended dispatch unattended. Trust stays a human decision, except one narrow, written rule for clones the orchestrator itself made from a repo the developer already trusts.
