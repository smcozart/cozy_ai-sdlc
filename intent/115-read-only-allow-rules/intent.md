# Intent: auto-mode workers are not stopped by false classifier denials of read-only commands

**Issue:** #115 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/.claude/settings.json", "plugin/skills/new-project/SKILL.md", ".claude/skills/new-project/SKILL.md", "plugin/skills/dispatch/SKILL.md", ".claude/skills/dispatch/SKILL.md"]` (provisional: triage picks one lever)

Moved from smcozart/cozy_observe#48 (closed there). The developer, 2026-10-16: "Yes, this issue needs to live in cozyharness", and "it might still make sense to go with this change since some harnesses are going to run in auto mode (espeically for enterprise)". Handed off with: "just have it file and understand the issue for the time being".

## Problem

Workers that `dispatch` starts run in Claude Code auto mode. The auto-mode classifier sometimes denies a command that only reads. After one denial, it often denies the next harmless command in the same session too.

Evidence (cozy_observe `/trace ai-sdlc,engineering-workflow`, 2026-10-16; review record smcozart/cozy_observe#22, comment 6220389085): 7 `permission_denial` deviations in 5 worker sessions. 4 windows from 2 sessions were read:

| Window | Session | Command | Denied as | Coverable by an allow rule |
|---|---|---|---|---|
| 4 | 40ff5180 | `cat docs/adr/0002-*.md ...; cat CONTEXT.md` | Irreversible Local Destruction | yes |
| 3 | 40ff5180 | read-only SELECT via `databricks experimental aitools tools query` | Irreversible Local Destruction | no: the tool can run any SQL |
| 35 | 13802e4d | `databricks workspace import --help; databricks jobs reset --help` | PII Data Handling | yes |
| 36 | 13802e4d | bulk `databricks fs cp -r` of the transcript volume | PII Data Handling | no: a fair block |

The other 3 denials (one each in 3 sessions, for example 24917146) are unread. In both sessions read, the denials came in pairs within 3 minutes. An orchestrator session (ff876c70) showed the same pair: after one denied merge, read-only `gh pr view` and `git worktree list` were denied as "Merge Without Review". Local transcripts show classifier denials from 2026-10-10 (17 to 2026-10-16), rising when worker swarms began.

**The evidence is thin today: 2 of 7 denials are known to be coverable.**

## What the plugin does today (main @ fb1d1d3)

- The `new-project` template ships no `.claude/` folder, so a scaffolded repo has no project allow rules.
- No skill (`new-project`, `dispatch`, `herdr-orchestrator`) names auto mode, permission rules or `.claude/settings.json`.
- Workers get only tracked files: `dispatch` worktrees under `<repo>/.factory/worktrees/` and `herdr-orchestrator` clones under `~/.factory/<repo>/workers/` both see the repo's committed `.claude/settings.json`, never an ignored or local one. cozy_observe ignores it (`.gitignore:12`), so its workers never get rules.

## Desired outcome

Repos that the ai-sdlc plugin sets up give their workers allow rules for evidenced read-only commands, in a file the workers actually get. Auto-mode workers are then not stopped by false denials. Or this issue records that project allow rules do not stop classifier denials, and that the fix belongs to Claude Code.

## Constraints (from cozy_observe#48)

1. **Count first.** Read all 7 denial windows. Stop if fewer than 5 are read-only and coverable by an allow rule.
2. **Prove the lever.** In a worker worktree in auto mode, show that a project allow rule stops a denial. Show that it does not cover secret paths (`~/.databrickscfg`, `.env`) or redirects (`cat a > b`).
3. **Tracked file.** The rules must be in a committed `.claude/settings.json`.
4. **Read-only only.** No rule that can write, delete, push, merge or send data out. No rule for a tool that runs arbitrary SQL.
5. **Human OK.** The rules widen what agents may run, so a named OK from the developer comes before they ship, even when the gate prints `flagged: no`.

## Open for triage

- **Which lever:** (a) the `new-project` template ships `.claude/settings.json` (new repos only, and adopted repos through the adopt PR), (b) the `dispatch` worker launch checks for the rules (every repo, at run time), or (c) the plugin ships the rules itself, if Claude Code lets a plugin set permissions (unverified).
- **Generic or per-stack:** the evidenced commands are `cat` of repo paths and `databricks … --help`. Only a generic core (repo-path reads, `--help`) fits a template. Stack rules belong to the project.
- **Enterprise:** a managed settings policy can restrict or ignore project rules. Check what the enterprise harness allows before choosing a lever.
- **Does it belong here at all:** if constraint 1 or 2 fails, close with the record and no plugin change.

## Non-goals

- Changing the classifier.
- Any write-capable rule (constraint 4).
- The cozy_observe-side rules and its intervention `i2`: those stay in cozy_observe.

## Acceptance criteria

- The count (constraint 1) and the auto-mode test (constraint 2) are on #115, with the commands, the rule, the worker session id, and whether each denial stopped and each secret path stayed uncovered.
- If the work goes on: the chosen lever writes a tracked `.claude/settings.json` with only evidenced read-only rules; `tests/validate.sh` passes on the range; the plugin and `.claude/skills/` copies match; the developer's named OK is on #115 before the merge.
- If it stops: #115 records why and closes with no plugin change.

## System-intent alignment

Keeps unattended workers unattended, without widening what they may change.
