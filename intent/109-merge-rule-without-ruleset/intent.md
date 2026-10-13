# Intent: a new repo never stalls every merge on a human by default

**Issue:** #109 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/skills/new-project/SKILL.md", ".claude/skills/new-project/SKILL.md", "plugin/templates/new-project/**", "plugin/skills/dispatch/SKILL.md", ".claude/skills/dispatch/SKILL.md"]`

## Problem

On a free private GitHub repo the ruleset is refused with HTTP 403. `new-project` then writes the fail-closed rule, and every PR waits for the developer, starting with the first records PR. The skill expects a `[]` read-back and does not name the 403 case. `dispatch` cites "ADR 0005" by cozyharness's number, and that number can mean something else in a scaffolded repo.

## Desired outcome

The merge rule for a repo without an enforced ruleset is the developer's choice, made once at setup, and written to the repo's own ADR. `dispatch` follows that ADR.

## Scope

- A 403 on the ruleset POST or the read-back is handled as "no ruleset".
- One setup question: the agent merges on a verified green `gate` (the `flagged: yes` hold stays human), or a human merges every PR, or upgrade to Pro or make the repo public.
- The scaffold writes the chosen rule into the adopt-workflow ADR and the Deploy enforcement line.
- `dispatch` Move 5 reads the merge rule from the repo's `docs/engineering-workflow.md` Deploy section, not from a fixed ADR number.

## Non-goals

- Any change to the `flagged: yes` hold.

## Acceptance criteria

- A `new-project` run against a free private repo asks the merge question once and writes the chosen rule. On "agent merges", the first records PR merges on a green gate with no developer action, and the `gh pr checks` line is pasted on the PR.
- A PR touching `tests/validate.sh` in that repo still waits for a human.
- No skill text cites a cozyharness ADR number for a rule that a scaffolded repo owns.
- `tests/validate.sh` passes on the range; the plugin and `.claude/skills/` copies match.

## System-intent alignment

Keeps a new project moving from its first PR, with human holds only where the developer chose them.
