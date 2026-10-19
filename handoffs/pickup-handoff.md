# Handoff: CozyHarness — session pickup (2026-09-13, late)

**From:** operator-orchestrator session · **For:** a fresh session continuing
work on the Harness. **Repo:** `smcozart/cozyharness`, branch `main`, pushed
**clean at `f66d79b`** (working tree = origin).
**Start here:** say "catch me up" (`cmu`) for the live picture; `STATUS.md`
is the review log.
THIS FILE is session context; the repo + tracker are the truth.

---

## What this system is (one paragraph)

The Harness is a portable, host-neutral AI-native SDLC process: humans
instigate/direct/govern, agents execute, all six stages are codified as
contracts in the repo. Works on **pi** (AGENTS.md, `.agents/skills/`,
`.pi/`) and **Claude Code** (CLAUDE.md, plugin, `.claude/skills/`, plus the
authored `.claude/verify-host.md` run). GitHub Issues is the tracker and the
join key. One gate: `tests/validate.sh` (+ `--witness`). Proof = pasted
output, hard decisions become pushed ADRs.

## Read first (fresh-session entrance ramp)

`cmu` → `AGENTS.md`/`CLAUDE.md` → `SYSTEM-INTENT.md` → `CONTEXT.md` →
`docs/engineering-workflow.md` → `REVIEW.md` →
`docs/training/onboarding-runbook.md` (incl. §4.5 for taking the harness into
a project like the RAG).

### Suggested skills
`engineering-workflow`, `factory-orchestrator` (now with **report-back = hard
contract**), `domain-modeling`, `tdd`/`implement`, `code-review` + the
`adversary` subagent, `handoff`. On Claude: `/setup-matt-pocock-skills` once.

---

## Where things stood (2026-09-13)

**Closed with proof:** six stages (#2#3#4#9#12#15) · Claude parity #19/#20 ·
hooks-core #21/#22 · lean pass #24/#25/#26 (light lane, single-source STATUS,
optional plan.md) · FO-skill report-back hardening (`73597d3`). Milestone tag
`v1-harness-complete`.

**Open frontier:** #1 hooks parent (pi event-advisor next) · #8 eval ledger ·
#18 two carried LOWs (owner: operator) · #23 hooks envelope (owner: operator,
needs a spec amendment).

**Queued next:** **Claude-host pipeline pilot** (Claude as orchestrator +
worker); then pi event-advisor (#1) and #23 refs-under-scrutiny.

## Ops facts that matter

- **Gates are human.** Issue-first → intent → spec → (optional plan.md) →
  tickets → build; close = pasted acceptance + green `tests/validate.sh [<range>`
  + merge-gate items (review, adversary, human checkoff, branch-protection
  403=absence). `ready-for-agent` = blockers resolved + acceptance defined.
- **Light lane exists** (#24): single/two-file, protected surface → thin
  front end (intent.md, no spec/plan) but SAME tail (proof + human gate).
- **Hooks are live** (git seam, installed by bootstrap): pre-commit sync
  trio, pre-push validate; local + bypassable (`--no-verify`/older clone),
  not a server.
- **Model op:** auto-route workers; ad hoc pin only when QC warrants —
  opus-4.8 as a worker pin; opus-5 blocked from pi (reasoning-effort 400).
  Adversary pass: kimi-k3 is the standing pick. Two-model disagreement →
  loop to agreement before blessing.
- **FO skill §6b = report-back is a hard contract:** worker MUST leave a
  `HANDOFF:` line AND direct-ping; idle pane with no HANDOFF line = dead spot
  the orchestrator must reconcile, never "assume it landed."  ADRs still
  pushed → tracked. (pushed at `73597d3`, all 3 copies byte-identical.)

## Environment

Fresh clone: `./bootstrap.sh` + `gh auth` → done. The gate travels into a
new project via runbook §4.5 (keep YOUR OWN SYSTEM-INTENT/CONTEXT/STATUS).

Nothing sensitive (no keys/PII) is here. Private = repo + tracker + gh cred.

## Jump back in

1. `gh issue list --state open` → frontier or the Claude pilot.
2. Say "catch me up" (`cmu`) + read the ramp above.
3. Gates are yours; a fresh session never self-approves.
4. Close with proof pushed.

**Good to continue the Harness from here.**