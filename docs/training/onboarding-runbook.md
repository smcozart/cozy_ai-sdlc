# Runbook: clone → bootstrap → first intake

> **Say "catch me up" (`cmu`) first** — it reads where the loop is, what's
> open, and what needs you from the tracker and git. This runbook is how to
> stand a machine up; `cmu` is where the process looks right now.

> `STATUS.md` is the review log; `handoffs/` is archival session
> context (repo-versioned), not a live source. The open issues list is
> the live frontier.

Standing up the Harness on a machine (pi or Claude Code) and starting the
first work item, end to end. README gives the one-liners; this walks through
what should happen at each step and what "worked on" looks like.

## 1. Clone and bootstrap

```bash
git clone git@github.com:smcozart/cozy_ai-sdlc.git && cd cozy_ai-sdlc
./bootstrap.sh
gh auth login   # if flagged — GitHub Issues is the tracker
```

`bootstrap.sh` is idempotent. It:

- Installs the Matt Pocock skills (Claude plugin, or copies them into
  `.agents/skills/` for pi).
- Installs the tools `.claude/settings.json` names, at project scope, if
  Claude Code is present: the cozysuite catalog, plus the Matt Pocock skills
  from `claude-plugins-official`.
- Installs the **local git-seam guardrail** (`core.hooksPath .githooks` —
  pre-push runs the Test gate before a push; silent when green).
- Checks `gh` auth.

"Worked" means: it exits clean (or only skips steps whose tool isn't
installed). `gh auth status` reports authenticated.

## 2. Pick a host

- **pi:** launch `pi` from the repo root and trust the project folder. It
  reads `AGENTS.md` at root, `.pi/`, and the skills in `.agents/skills/`: the
  tracked `ponytail` and the Matt Pocock copies `./bootstrap.sh` restores. It
  does not load the `plugin/skills/` skills.
- **Claude Code:** launch `claude`. `CLAUDE.md` points at `AGENTS.md`; the
  `plugin/` skills are live through the `.claude/skills/` symlinks.

Both hosts run the same contracts; only the launch differs.

## 3. Prove the suite is green (baseline)

```bash
tests/validate.sh            # one ok: line per check, then "N ok, 0 failed",
                             # exit 0 (the check names: tests/validate.sh --list)
tests/validate.sh --witness  # replay fail-first witnesses; needs full history
                             # (shallow clone → `git fetch --unshallow`)
```

A green suite is the floor every project close is measured against.

## 4. The first work item — issue-first intake

Every unit of work starts as a GitHub issue before any artifact. Gates are
held by the human operator; the agent never pre-decides scope.

1. **Parent issue** — problem, desired outcome, scope, non-goals.
2. **Intent** — `intent/<issue-number>-<slug>/intent.md` from
   `intent/TEMPLATE.md`, aligned with `SYSTEM-INTENT.md`; operator approves it
   in the thread before it moves to Design.
3. **Tickets** — there is no `spec.md` (ADR 0008): the intent is the design
   record; `/to-tickets` cuts vertical-slice child issues with blocking edges
   (ADR 0002).
4. **`ready-for-agent`** = blockers resolved + acceptance criteria defined;
   no label, no work.
5. **Build** — one ticket per session, test-first, proof-over-claim.

**One review lane** (ADR 0008): every PR, large or small, closes the same
way — `ready-for-agent`, green `tests/validate.sh`, one adversary pass, and a
human merge when `flagged: yes`. See the review-lane section of
`docs/engineering-workflow.md`.

For a large, half-planned piece it's the entrance ramp: walk research +
drafted docs through intake, then the questionnaire → grilling →
ticket-cut gates split it into tractable slices before any code.

## 4.5 Take the harness INTO your project (e.g. a RAG system)

Everything above stands up the harness in THIS repo. A different codebase
(say a RAG system) scaffolds from the plugin's template, with no manual `cp`.
In YOUR project repo:

1. Get the tools from the cozysuite catalog (github.com/smcozart/cozysuite,
   "Set up a project"; the `core` preset carries ai-sdlc).
2. Say "start a new project" (ai-sdlc `new-project`). It scaffolds the
   workflow files, the gate (`tests/validate.sh`) and the CI `gate`
   workflow, then hands off to intake.

Then the same cycle in §4 runs against YOUR repo. Keep your OWN
`SYSTEM-INTENT.md`, `CONTEXT.md` and `STATUS.md`; never copy this repo's.

## 5. Close with proof

Closing pastes the acceptance-criteria output AND the
`tests/validate.sh [<range>]` run (plus the fail-first pair for a fix),
then the Deploy merge-gate items (review, adversary, human checkoff). See
`REVIEW.md` and the Deploy section of `docs/engineering-workflow.md`.

## Caveats

- **Local guardrails, not a server.** The git-seam hook (pre-push
  validate), installed by `bootstrap.sh`, are local and
  bypassable by design: a clone that never bootstraps `core.hooksPath`, or a
  `git push --no-verify`, sails through unblocked
  — the required CI `gate` check on every PR into `main` (#33) is the
  backstop. A green
  `validate.sh` is necessary, not sufficient.
- **Still paper/staged:** the QC findings ledger (#8) and the carried
  findings (#18) are open; gates like the merge gate are pasted-evidence plus
  your human judgment. The hooks check only the deterministic seams.
- **Private repo:** the clone needs `gh` auth and repo access on the new
  machine; GitHub Issues is the system of record.
