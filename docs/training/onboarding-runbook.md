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
- Installs the tools `.claude/settings.json` names, at project scope, from the
  cozysuite catalog, if Claude Code is present.
- Installs the **local git-seam guardrails** (`core.hooksPath .githooks` —
  pre-commit enforces the sync rule per-commit, pre-push runs the Test gate
  before a push; silent when green).
- Checks `gh` auth.

"Worked" means: it exits clean (or only skips steps whose tool isn't
installed). `gh auth status` reports authenticated.

## 2. Pick a host

- **pi:** launch `pi` from the repo root. It reads `AGENTS.md` at root, the
  `.agents/skills/` copies, and `.pi/`. No extra step.
- **Claude Code:** launch `claude`. `CLAUDE.md` points at `AGENTS.md`; the
  `plugin/` + `.claude/skills/` copies are live. Run `/setup-matt-pocock-skills`
  once to scaffold this repo's tracker labels + ADR layout.

Both hosts run the same contracts; only the launch differs.

## 3. Prove the suite is green (baseline)

```bash
tests/validate.sh            # 14× ok, then "14 ok, 0 failed", exit 0
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
3. **Spec + tickets** — `/to-spec` writes `intent/<n>-<slug>/spec.md` beside
   the intent (ADR 0001, not into the issue body); `/to-tickets` cuts
   vertical-slice child issues with blocking edges (ADR 0002).
4. **`ready-for-agent`** = blockers resolved + acceptance criteria defined;
   no label, no work.
5. **Build** — one ticket per session, test-first, proof-over-claim.

**Light lane** (small, low-risk change — single/two-file, docs-only or
non-speculative, no protected surface, no ADR-earning decision, no multi-edge
blocker): a short `intent.md` only (no `spec.md`/`plan.md`), then the *same*
close — `ready-for-agent`, green `tests/validate.sh`, human checkoff. A defined
lane, not a loophole; the close gate never relaxes. See the light-lane section
of `docs/engineering-workflow.md`.

For a large, half-planned piece it's the entrance ramp: walk research +
drafted docs through intake, then the questionnaire → spec → grilling →
ticket-cut gates split it into tractable slices before any code.

## 4.5 Take the harness INTO your project (e.g. a RAG system)

Everything above stands up the harness in THIS repo (cozyharness). When the
work lives in a **different** codebase — say a RAG system you're planning —
the harness travels there; it isn't cloned in wholesale:

```bash
# clone once, from this repo as a portable reference
git clone git@github.com:smcozart/cozy_ai-sdlc.git /tmp/harness-ref
cd /your-rag-project                                  # or wherever the work lives
cp -R /tmp/harness-ref/bootstrap.sh \                # carry the scaffolding over
      /tmp/harness-ref/skills-lock.json \
      /tmp/harness-ref/plugin \
      /tmp/harness-ref/.claude-plugin \
      /tmp/harness-ref/AGENTS.md \
      /tmp/harness-ref/CLAUDE.md .
./bootstrap.sh                                         # installs hooks + skills
gh auth login                                          # track via YOUR GitHub issues
claude   # then: tools per the cozysuite README ("Set up a project"), and /setup-matt-pocock-skills once
```

Then the same cycle in §4 — issue-first
intake → spec → tickets → build — runs against YOUR repo: the harness files
now live in YOUR project, the SAME gate (`tests/validate.sh`), the same
seams. Your intents live in `intent/<n>-<slug>/` — keep your OWN
`SYSTEM-INTENT.md` and `CONTEXT.md` (your RAG's purpose and vocabulary) and
start your OWN `STATUS.md` review log from its header. Don't copy cozyharness's
`STATUS.md` — its lines acknowledge this project's reviews, not yours.

> The git-seam guardrails from §1 install in your project too (`bootstrap.sh`
> sets `core.hooksPath` locally). If the RAG lives on a different git host
> (e.g. Azure DevOps), the git seams are the same — the gate travels.

## 5. Close with proof

Closing pastes the acceptance-criteria output AND the
`tests/validate.sh [<range>]` run (plus the fail-first pair for a fix),
then the Deploy merge-gate items (review, adversary, human checkoff). See
`REVIEW.md` and the Deploy section of `docs/engineering-workflow.md`.

## Caveats

- **Local guardrails, not a server.** The git-seam hooks (pre-commit
  sync-rule, pre-push validate), installed by `bootstrap.sh`, are local and
  bypassable by design: a clone that never bootstraps `core.hooksPath`, or a
  `git push --no-verify` / `git commit --no-verify`, sails through unblocked
  — the required CI `gate` check on every PR into `main` (#33) is the
  backstop. A green
  `validate.sh` is necessary, not sufficient.
- **Still paper/staged:** the eval harness (#8) and two carried findings
  (#18) are outstanding; gates like the merge gate are pasted-evidence plus
  your human judgment. The hooks check only the deterministic seams.
- **Private repo:** the clone needs `gh` auth and repo access on the new
  machine; GitHub Issues is the system of record.
Handoff note (gate test): the required `gate` check is live; PR bodies carry an `ADR:` line.
