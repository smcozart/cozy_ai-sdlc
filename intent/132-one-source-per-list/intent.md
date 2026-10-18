# Intent: one source per list — documents point to LANE_HOLD, skill copies become symlinks

**Issue:** #132 · **Status:** approved · **Type:** system-change

**Touches:** `["tests/validate.sh", "AGENTS.md", "CLAUDE.md", ".gitignore", "README.md", "REVIEW.md", "CONTRIBUTING.md", "docs/engineering-workflow.md", "docs/adr/0003-review-effort-follows-a-computed-lane.md", "docs/adr/0005-auto-merge-on-green.md", "plugin/skills/engineering-workflow/SKILL.md", "plugin/skills/herdr-orchestrator/SKILL.md", ".claude/skills/**", ".agents/skills/herdr-orchestrator"]`

From the harness review, Sean, 2026-10-18 (item 1, "go … work in the risks you've spotted"). Covers #63.

## Problem

- The hold list is written out in these files: `AGENTS.md`, `README.md`, `REVIEW.md`, `docs/engineering-workflow.md`, ADR 0003, ADR 0005, the `engineering-workflow` skill, the `herdr-orchestrator` skill, and their copies. #131 changed 3 regex alternatives and touched 12 files.
- The 6 plugin skills have hand-kept copies in `.claude/skills/`, and `herdr-orchestrator` also has one in `.agents/skills/`. `skill-copies` (`tests/validate.sh`) only checks that the copies match. Every skill edit is made 2 or 3 times.

## Desired outcome

- **One source for the hold list.** The list exists only in `LANE_HOLD` in `tests/validate.sh`. Each document states the policy in words, for example "the files that check other files hold; the list is `LANE_HOLD` in `tests/validate.sh`; `tests/validate.sh --lane` prints `flagged:`". It does not copy the paths.
- **ADR 0005 keeps the decision** and points to `LANE_HOLD` as the one list. Record this as an "Amended" paragraph, in the same form ADR 0004 uses.
- **One source for each skill.** `.claude/skills/<name>` is a directory symlink to `../../plugin/skills/<name>`, for each of the 6 plugin skills. `.agents/skills/herdr-orchestrator` is a symlink to `../../plugin/skills/herdr-orchestrator`. `.agents/skills/ponytail` is not a copy, so it stays as it is.
- **`skill-copies` becomes `skill-links`.** It checks each of these entries in the working tree:
  - it is a symlink (`[ -L ]`);
  - `readlink` equals `../../plugin/skills/<name>`;
  - it resolves to a directory that has a `SKILL.md`.

  The index mode alone (`git ls-files -s` `120000`) is not enough: a checkout without symlinks still reports `120000`.
- **`.gitignore`:** change `!.agents/skills/herdr-orchestrator/` to `!.agents/skills/herdr-orchestrator`, without the trailing slash. With the slash, git ignores the symlink and `git add` refuses it.
- **`CLAUDE.md`:** "(copies of `plugin/skills/`)" becomes "(symlinks to `plugin/skills/`)".
- **Old witness rows:** delete the rows that append to `.claude/skills/*/SKILL.md` (`tests/validate.sh`, near 370-381). Through a symlink they would write into `plugin/skills/`.

## Risk handling (Windows)

A checkout with `core.symlinks=false` writes each link as a small text file. The skills in `.claude/skills/` then do not load.

- `skill-links` fails on such a checkout. Its message names the fix: "enable symlinks (`git config core.symlinks true`, Windows Developer Mode) and re-checkout".
- `CONTRIBUTING.md` says the same in one line.
- Before switching, verify on this Mac that Claude Code loads a project skill through a directory symlink. Run, in the worker clone after the change: `claude -p "List the names of the project skills you can see, one per line."` The output must name all 6 skills without the `ai-sdlc:` prefix. The installed plugin shows the prefixed names, so a prefixed name proves nothing. If a host does not load symlinked skills, stop. Report it on #132 and do not switch. The fallback (copies plus a generator command) needs a new decision.
- pi reads `.agents/skills/`. If `pi` is installed, check it the same way. If it is not installed, say so on #132.

## Non-goals

- The consumer template's own documents (`plugin/templates/new-project/files/**`). They describe the consumer's hold list, which rarely changes.
- `bootstrap.sh` and `docs/training/onboarding-runbook.md`. They name `.githooks` as the hooks path, not the hold list.
- The `sync-rule` check (doc, SKILL.md and README move together). It guards something else.

## Acceptance criteria

- `git grep -nE 'githooks/\*\*|\.githooks/\)' -- '*.md' ':!intent' ':!handoffs' ':!plugin/templates'` finds no list of hold paths, only pointers to `LANE_HOLD`. Paste the command and its output.
- In a scratch copy, add one alternative to `LANE_HOLD`. `git diff --stat` shows 1 file (2 if a witness row is added), and `bash tests/validate.sh` passes in that copy.
- `git ls-files -s .claude/skills .agents/skills/herdr-orchestrator` shows mode `120000` for the 7 links.
- `skill-links` witnesses:
  - a link replaced by a regular file: FAIL;
  - a link to the wrong target: FAIL;
  - a dangling link: FAIL;
  - a good tree: ok.
- The `claude -p` skill listing above names all 6 skills.
- `bash tests/validate.sh --witness` passes. `bash tests/validate.sh origin/main..HEAD <body>` exits 0 with `flagged: yes`, because `tests/validate.sh` changes. A named human merges.

## System-intent alignment

Keeps the harness small and sharp: one place to change each fact, and drift fails loudly.
