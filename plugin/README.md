# AI SDLC Plugin (`ai-sdlc`, Claude Code)

Packages the repo's engineering process as a Claude Code plugin: skills,
no external deps beyond `gh` and the `mattpocock-skills`
plugin it declares as a dependency.

## Adoption order (canonical — one command on a new machine)

```bash
git clone <this-repo> && cd <repo-name>
./bootstrap.sh   # installs the tools .claude/settings.json names (project
                 # scope, cozysuite catalog); pi: Matt Pocock copies from
                 # the lock; verifies vendored ponytail, checks gh auth;
                 # re-runnable
```

Then: `gh auth login` if flagged, and `herdr` only for parallel builds. A NEW
repo gets its branch protection from `new-project` Move 4
(`plugin/skills/new-project/SKILL.md`): the ruleset and the required `gate`
check that ADR 0005 needs.

Fresh agent session on an existing repo: read `CLAUDE.md` or `AGENTS.md` if
present, then `docs/engineering-workflow.md` → `gh issue list --label
ready-for-agent`.

## Install

```
claude plugin marketplace add smcozart/cozysuite --scope project
claude plugin install ai-sdlc@cozysuite --scope project
```

This also installs `mattpocock-skills` from `claude-plugins-official`. Or run
`/cozysuite:setup` and pick the `core` preset. Never user scope.

To try a working copy of the plugin for one session: `claude --plugin-dir plugin`
from this repo.

After install, verify: `/plugin` shows `ai-sdlc`; the `dispatch` skill is
available.

## Dependencies (not bundled — install per below)

The plugin is self-contained for the *process*; three dependency classes sit
outside it:

1. **Matt Pocock skills** (`mattpocock/skills`): Claude gets the official
   managed plugin, installed with ai-sdlc at project scope. pi gets editable copies restored by `./bootstrap.sh` from
   `skills-lock.json` (full skill dirs incl. `agents/` subdirs; provenance =
   upstream HEAD sha, printed at restore time).
   The dependency carries no `version`: Claude Code resolves a dependency
   `version` range only against `<plugin-name>--v<version>` git tags
   ([plugin dependencies](https://code.claude.com/docs/en/plugins/dependencies.md)),
   and `mattpocock/skills` tags `v<version>`, so a range would fail the install.
   Without a version, the dependency moves to each new release its marketplace
   publishes the next time a project updates, so projects that update at different times drift apart
   (the same docs page); bring one up to date with
   `claude plugin update mattpocock-skills@claude-plugins-official --scope project`
   from the project folder.
2. **Ponytail** (lean-code discipline, github.com/DietrichGebert/ponytail,
   MIT): forces stdlib-first, shortest-diff, no-speculative-abstraction coding.
   `docs/engineering-workflow.md` Build §2 states its core rules, but the full
   skill (intensity modes, persistence) installs separately — in pi via its
   skill-git mechanism; in Claude Code, `ponytail@cozysuite` (in the
   `core` preset).
3. **CLIs**: `gh` (authenticated — the tracker depends on it) always; `herdr`
   only for parallel orchestrated builds (`dispatch`'s herdr row).

## What's inside

- `skills/` — `intent-conversation`, `dispatch` (its first host row is herdr,
  which needs `herdr` on PATH), `cmu` and `new-project`

## The replication pattern (how to do this for other harnesses)

The **repo is the source of truth**; plugins/adapters are build artifacts:

1. Canonical content lives in-repo: `docs/engineering-workflow.md` (the
   process), `docs/adr/` (decisions), `skills-lock.json` (third-party skill
   manifest).
2. Each harness gets a thin adapter generated from that canon:
   - **Claude Code**: this plugin (skills).
   - **pi**: no adapter needed — `.pi/agents/`, `.pi/prompts/` and
     `.agents/skills/` are its own formats. `git clone` restores `.pi/` and
     `.agents/skills/ponytail`; `./bootstrap.sh` restores the Matt Pocock
     copies in `.agents/skills/` (`.gitignore` keeps them out of git). pi
     loads `.agents/skills/` in a trusted project; it does not load the
     `plugin/skills/` skills.
3. Never fork the process text. Adapters point at or are generated from the
   canonical doc; when the process changes, it changes in `docs/`, and each
   adapter is regenerated.

Rule of thumb: *if a harness can read the repo, it needs only a pointer; if it
can't, it gets a generated bundle from the canonical source.*