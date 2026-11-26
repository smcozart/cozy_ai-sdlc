# The Harness

An AI-native software development process, packaged to run on Claude Code and
pi today. It is a concrete
implementation of Anthropic's six-phase SDLC loop — Plan → Design → Build →
Test → Deploy → Maintain — where Maintain feeds back into Plan, the loop turns
in hours, and **humans stay above the loop: instigating, directing, governing.**

## What you get

- **The process** — a six-phase workflow where every unit of work (system,
  feature, or bug fix) starts from a written intent (the "why"), gets structured
  into GitHub issues with blocking edges and triage labels, gets built by agents
  test-first, gets verified by pasted proof (never claims), and records every
  hard-to-reverse decision as a versioned ADR.
- **The contracts** — `ready-for-agent` means blockers resolved + acceptance
  criteria defined; no label, no work. Closing an issue requires verification
  output. The tracker is the system of record.
- **The packaging** — a Claude Code plugin, pi project skills, a bootstrap
  script, and config files that remove setup guesswork.

The six stages, their contracts and the merge policy: [`docs/engineering-workflow.md`](docs/engineering-workflow.md).

## Quick start

```bash
git clone <this-repo> && cd <repo-name>
./bootstrap.sh          # restores skills (upstream copies + vendored),
                        # installs the tools .claude/settings.json names at
                        # project scope (the cozysuite catalog, plus the Matt
                        # Pocock skills from claude-plugins-official),
                        # checks gh auth
gh auth login           # if flagged — GitHub Issues is the tracker
claude                  # plugin + skills are live
```

On YOUR project repo (the one you'll build in): get the tools from the
cozysuite catalog (github.com/smcozart/cozysuite, "Set up a project"; the
`core` preset carries ai-sdlc), then say "start a new project" (ai-sdlc
`new-project`) to scaffold the workflow files. Full detail: `plugin/README.md` and
`docs/engineering-workflow.md`.

## How it's organized

| Path | What it is |
|---|---|
| `docs/engineering-workflow.md` | The canonical process document |
| `docs/adr/` | Architecture decision records — the system's memory |
| `CONTEXT.md` | Shared domain vocabulary — the glossary every artifact uses |
| `intent/` | Work-item intents (`TEMPLATE.md`) |
| `docs/agents/` | Per-repo agent config (tracker, labels, domain docs) |
| `plugin/` | Claude Code plugin (skills) |
| `bootstrap.sh` | One-command setup on any machine |
| `skills-lock.json` | Pinned manifest of third-party skills |

## Why it scales

Decisions accumulate in ADRs, process improvements accumulate in the versioned
workflow doc, proof accumulates in issues, and the tracker is the join key
between humans, sessions, and machines. Any agent harness (pi, Claude Code,
Copilot) can take the center of the loop, because the contracts live in the
repo, not the tool.

## Iterating on it

This repo dogfoods its own process — see `CONTRIBUTING.md`. Process changes
land as PRs with an ADR when the change is a real decision; the workflow doc
and this README are updated in the same commit so they never drift.