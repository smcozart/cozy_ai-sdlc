# The Harness

An AI-native software development process, packaged to run on Claude Code and
pi today (GitHub Copilot advisory support included). It is a concrete
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

```
Plan ────► issue-first intake, then intent: the why (outcome, scope,
          non-goals) at intent/<issue-number>-<slug>/intent.md,
          aligned with SYSTEM-INTENT.md — human-approved; intake never waits
Design ──► spec.md beside the intent; ADRs over the bar; vertical-slice
          tickets as child issues with blocking edges; approval gate;
          a settled decision is a record in the same turn (ADR, spec
          section, or ticket body); settling approves the decision;
          settling is not a merge approval — the record merges only under
          the repo's merge policy (ADR 0005)
Build ───► one ticket per agent session; workers cite ADRs, write ADRs
          (optional plan.md sequences tickets for multi-ticket builds — not
          the agent's per-session plan-before-code)
Test ────► tests/validate.sh exits 0 (fail-first; checks and the content
          they guard protected) — run + acceptance output (+ pair for fixes)
          pasted at close; CI runs it on every PR (check `gate`)
Deploy ──► review loop per REVIEW.md; merge gate pasted (review resolution,
          validate.sh run, adversary verdict, preview proof for UI,
          branch-protection proof for merge path, `ADR:` line in the PR
          body); merge policy (ADR 0005): the hold list (validate.sh,
          .github/workflows/**, .githooks/**; `flagged: yes`) merges on a
          named human checkoff, everything else lands on green with review
          after merge — while `gate` is advisory, the human checkoff is the
          gate; a 401 is not evidence of absence — authenticate first
Maintain ─► intake: retros/incidents feed back through Plan; fixed incident classes → eval ledger (#8)
```

**Light lane, computed.** `tests/validate.sh --lane <range>` classifies a
diff from what git sees, as an allow-list — **T0** (≤2 docs files, all in the
light set: gate run + human review after merge, no adversary pass), **T1** (small and in
the light set, or the board / runbook floor: one bounded adversary pass),
**T2** (anything else — unknown paths, instruction files, deletes, symlinks, >2 files
or >60 lines: the full review loop). T0/T1 take a thinner front end — a short `intent.md`,
**no** `spec.md`/`plan.md` — and a smaller review budget, and close through
the *same* gate: `ready-for-agent`, pasted `tests/validate.sh`, the same
merge policy. The agent confirms two clauses the classifier cannot see (earns no
ADR, not speculative) and may only escalate. A defined lane, not a loophole;
nothing about the close gate relaxes. Detail: `docs/engineering-workflow.md`,
ADR 0003. The same run prints `flagged: yes|no` — `yes` when the range touches
the merge hold list (`tests/validate.sh`, `.github/workflows/**`,
`.githooks/**`; ADR 0005), so a human merges.

## Quick start

```bash
git clone <this-repo> && cd <repo-name>
./bootstrap.sh          # restores skills (hash-tracked upstream + vendored),
                        # registers the Claude plugin, checks gh auth
gh auth login           # if flagged — GitHub Issues is the tracker
claude                  # plugin + skills are live
```

On YOUR project repo (the one you'll build in): copy in `bootstrap.sh`,
`skills-lock.json`, `plugin/`, and `.claude-plugin/`, run `./bootstrap.sh`,
then run `/setup-matt-pocock-skills` once to scaffold that repo's tracker
labels and ADR layout. Full detail: `plugin/README.md` and
`docs/engineering-workflow.md`.

## How it's organized

| Path | What it is |
|---|---|
| `docs/engineering-workflow.md` | The canonical process document |
| `docs/adr/` | Architecture decision records — the system's memory |
| `CONTEXT.md` | Shared domain vocabulary — the glossary every artifact uses |
| `intent/` | Work-item intents (`TEMPLATE.md`) and specs (`TEMPLATE-spec.md`) |
| `docs/agents/` | Per-repo agent config (tracker, labels, domain docs) |
| `plugin/` | Claude Code plugin (skills + session hook) |
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
and the plugin skill are updated in the same commit so they never drift.