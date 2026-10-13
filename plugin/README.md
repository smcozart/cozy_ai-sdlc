# Engineering Workflow Plugin (Claude Code)

Packages the repo's engineering process as a Claude Code plugin: skills,
session-start hook, no external deps beyond `gh`.

## Adoption order (canonical — one command on a new machine)

```bash
git clone <this-repo> && cd <repo-name>
./bootstrap.sh   # restores Matt Pocock skills (Claude: official managed
                 # plugin; pi: editable copies from the lock), verifies
                 # vendored ponytail, registers the Claude plugin,
                 # checks gh auth; re-runnable
```

Then: `gh auth login` if flagged, `herdr` only for parallel builds, branch
protection (command below) once per repo, and `/setup-matt-pocock-skills` once
per NEW repo only (this repo already carries `docs/agents/` config).

```bash
gh api repos/<owner>/<repo>/rulesets -X POST \
  -H "Accept: application/vnd.github+json" -f name='protect-main' \
  -F target='branch' -f 'conditions[ref_name][include][]=refs/heads/main' \
  -F 'rules[][type]=deletion' -f 'enforcement=active'
```

Fresh agent session on an existing repo: read `CLAUDE.md` or `AGENTS.md` if
present, then `docs/engineering-workflow.md` → `gh issue list --label
ready-for-agent`.

## Install

From this repo (local path install):

```bash
claude plugin add /path/to/repo/plugin
```

Or host a marketplace later by adding `.claude-plugin/marketplace.json` at repo
root and pointing other machines at the GitHub URL.

After install, verify: `/plugin` shows `engineering-workflow`; a new session
prints the workflow reminder; the `engineering-workflow` skill is available.

## Dependencies (not bundled — install per below)

The plugin is self-contained for the *process*; three dependency classes sit
outside it:

1. **Matt Pocock skills** (`mattpocock/skills`): Claude gets the official
   managed plugin (`claude plugin install mattpocock-skills` — updates when
   upstream ships). pi gets editable copies restored by `./bootstrap.sh` from
   `skills-lock.json` (full skill dirs incl. `agents/` subdirs; provenance =
   upstream HEAD sha, printed at restore time).
2. **Ponytail** (lean-code discipline, github.com/DietrichGebert/ponytail,
   MIT): forces stdlib-first, shortest-diff, no-speculative-abstraction coding.
   The workflow skill encodes its core rules in the Build phase, but the full
   skill (intensity modes, persistence) installs separately — in pi via its
   skill-git mechanism; in Claude Code, vendor `SKILL.md` into
   `~/.claude/skills/ponytail/` if you want the complete version.
3. **CLIs**: `gh` (authenticated — the tracker depends on it) always; `herdr`
   only for parallel orchestrated builds (herdr-orchestrator skill).

## What's inside

- `skills/engineering-workflow/` — the six-phase process (plan intent → design
  tickets+ADRs → build → test proof → deploy → maintain intake)
- `skills/herdr-orchestrator/` — herdr multi-agent orchestration (only used
  when doing parallel builds; needs `herdr` on PATH). `factory-orchestrator` is
  now `herdr-orchestrator`.
- `hooks/hooks.json` — UserPromptSubmit reminder keeping the process in-context

## The replication pattern (how to do this for other harnesses)

The **repo is the source of truth**; plugins/adapters are build artifacts:

1. Canonical content lives in-repo: `docs/engineering-workflow.md` (the
   process), `docs/adr/` (decisions), `.agents/skills/` (pi skills),
   `skills-lock.json` (third-party skill manifest).
2. Each harness gets a thin adapter generated from that canon:
   - **Claude Code**: this plugin (skills + hooks).
   - **GitHub Copilot**: `.github/copilot-instructions.md` (advisory pointer;
     enforcement comes from branch protection + the tracker).
   - **pi**: no adapter needed — `.agents/skills/`, `.pi/agents/`,
     `.pi/prompts/` ARE its plugin format, restored by `git clone`.
3. Never fork the process text. Adapters point at or are generated from the
   canonical doc; when the process changes, it changes in `docs/`, and each
   adapter is regenerated (or, where it embeds a copy like the skill above,
   updated in the same commit).

Rule of thumb: *if a harness can read the repo, it needs only a pointer; if it
can't, it gets a generated bundle from the canonical source.*