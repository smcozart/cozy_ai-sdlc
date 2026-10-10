---
name: engineering-workflow
description: The standard engineering process for this org — use when starting any engineering work (new project, feature, or bug fix), when planning, ticketing, triaging, implementing, reviewing, or recording decisions. Defines the six-phase loop (Plan/Design/Build/Test/Deploy/Maintain) and its contracts.
---

# Engineering Workflow

The standard process. Applies to every unit of work: new system, feature, or
bug fix. Six phases; each resolves to a durable artifact, mostly GitHub objects.

```
Plan → Design → Build → Test → Deploy → Maintain ──► back to Plan
```

## Phase 0: Prerequisites (once per repo)

1. `gh` authenticated — GitHub Issues is the tracker; issue numbers are the
   join key between humans, sessions, and machines.
2. If the repo has no triage labels yet or no `docs/adr/`, run
   `/setup-matt-pocock-skills` before anything else. It scaffolds the per-repo
   config the other skills assume: tracker location, the triage label
   vocabulary (ending in `ready-for-agent`), and domain doc layout
   (`CONTEXT.md`, `docs/adr/`). Without it, to-tickets and triage have no
   defined destination. Run once per REPO, not per machine.
3. Onboarding order for a fresh session on an existing repo: read `CLAUDE.md` or
   `AGENTS.md` if present, then `docs/engineering-workflow.md` → `gh issue list --label
   ready-for-agent`. That sequence reconstructs full context from the repo
   alone — never from chat history.

## Plan — issue-first intake, intent & the why

Every request becomes a GitHub issue **first** — problem, desired outcome,
scope, non-goals. Multiple requests in one conversation split into separate
issues (with blocking edges if related); one request, one issue, no side-lists
in chat. Intake never waits (ADR 0004): file the next request the moment it
is said, even mid-build; a dependent request is filed as its own issue with a
blocking edge to the one ahead of it (mechanics:
`docs/agents/issue-tracker.md`), never held for later batching.

After triage clarification, capture the agreed why as **work-item intent** at
`intent/<issue-number>-<slug>/intent.md` (template: `intent/TEMPLATE.md`). The
issue number joins issue, intent, branch, PR, and proof. Check the intent
against `SYSTEM-INTENT.md` (the system's enduring purpose) — conflicts amend
it deliberately or rewrite the intent. Bug fixes seed the intent from the
diagnosis; features from the brief; PRDs from transcripts.

**Approval:** normal work is approved conversationally in the issue thread
(`ready-for-agent` = approved to proceed). High-risk work (security, data
loss, irreversible migrations, public contracts) requires explicit human
review sign-off in the issue, recorded as an ADR. No approved intent, no work.

The intent is the lighthouse — everything downstream is graded against it.
The Plan artifact is the intent; an optional `plan.md` (ticket/ADR execution
sequencing) is written after Design only for multi-ticket builds with a real
order to record — single-ticket work skips it, and it is never the agent's
always-kept per-session plan-before-code.

## Design — spec, ADRs, tickets, and the approval gate

1. **spec.md**: the spec for issue `#n` lives at
   `intent/<n>-<slug>/spec.md`, a sibling of the intent (ADR 0001), its
   header linking back to the issue and intent; the issue links to it by
   path. Never copy the spec into the issue body. Required sections:
   problem statement, requirements (user stories), design concerns
   (modules/interfaces/seams), constraints (system/UX/security), testing
   decisions, out of scope, open questions. Template:
   `intent/TEMPLATE-spec.md`.
2. **ADRs**: a decision that is hard to reverse, surprising without context,
   or a real trade-off gets a one-paragraph record in `docs/adr/NNNN-slug.md`,
   committed and pushed immediately. Tech-stack preferences and conventions
   live here too — shared brain for every agent. Existing ADRs constrain new
   design: contradictions are surfaced or superseded, never silently
   overridden.
3. **Tickets**: break the spec into vertical-slice sub-issues of the design
   issue (ADR 0002), each with explicit blocking edges via native `blocked_by`
   dependencies where available, else a `Blocked by: #n` body line
   (mechanics: `docs/agents/issue-tracker.md`), runnable acceptance criteria,
   and spec/ADR references. Triage labels move issues
   through their state machine; issues end as **`ready-for-agent`** (blockers
   resolved + acceptance criteria defined). The label is a
   contract: no label, no work. The linked-issue graph IS the design.
4. **Approval gate**: ordinary design is approved conversationally in the
   issue thread; high-risk work (security, data loss, irreversible
   migrations, public contracts) needs explicit human sign-off in the issue
   plus an ADR.
5. **Build read order**: issue → spec → ADRs → `CONTEXT.md` → code.
   Greenfield and brownfield run the same workflow; only the seed differs
   (brief/PRD vs diagnosis/retro).
6. **A settled decision becomes a record in the same turn** (ADR 0004):
   "let's go with X" / "lock that in" / "we decided" lands before the next
   question, never held for later batching — a hard-to-reverse or
   authority rule becomes a new ADR; a requirement or design detail becomes
   an edit to the spec's matching section; a detail scoped to one ticket
   becomes an edit to that issue's body. Settling approves the decision.
   Settling is not a merge approval — the record merges only under the
   repo's merge policy (ADR 0005). No separate sign-off on the decision is owed
   beyond item 4's high-risk carve-out. Reply in one line naming the
   record. "Captured in this conversation only" and "finish mapping first,
   then update once" are not moves; batch only when asked.

## Light lane — thin front end, same tail

A small, low-risk change takes a thinner front end and a smaller review
budget. **The lane is computed, then confirmed** (ADR 0003): run
`tests/validate.sh --lane <range>` over the ticket's full range and paste its
`lane:` line beside the gate run. The classifier is an **allow-list** —
unknown is heavy. **T0 trivial** — ≤2 files, all `*.md`, ≤60 lines, every
file in the light set (`handoffs/`, `docs/training/`, `STATUS.md`, `LICENSE`
here) and none on the T1 floor: the gate run + the human review (after merge
unless held), no adversary pass. **T1 light** — same limits, or any file on the T1 floor
(`STATUS.md`, `docs/training/`, `handoffs/pickup-handoff.md`):
the gate run + one bounded adversary pass (the diff's claims, MED+ findings
only). **T2 heavy** — anything outside the light set, any instruction file
wherever it sits, in any case (`CLAUDE.md`, `AGENTS.md`, `README.md`, `.mcp.json`,
`.cursorrules`, `.gitmodules`), any delete, binary or symlink, >2 files or >60 lines:
the full review loop. A range marked PARTIAL, a missing `--lane`, or no
`lane:` line all mean **T2**. The classifier sees files, not meaning, so the
agent fills in two clauses at close — `no-ADR=<y/n> not-speculative=<y/n>` —
and any `n` means T2. Escalate only; never lower a computed lane. Consumers
extend the light set, never the heavy one. The same run prints `flagged: yes|no` —
`yes` when the range touches the merge hold list (`tests/validate.sh`,
`.github/workflows/**`, `.githooks/**`; ADR 0005), so a human merges; it is
the hold list only, not the former Deploy flagged-risk set.

Shape: a short `intent/<n>-<slug>/intent.md` only — problem, one-line outcome,
scope, acceptance — with **no** `spec.md` and **no** `plan.md`. The tail is
identical to every close: the same `ready-for-agent` contract, the same pasted
`tests/validate.sh [<range>]` proof, the same merge policy. It is a defined
lane, **not** a loophole — nothing about the close gate relaxes, the lane
never decides who merges (the merge hold does, and the hold list stays
human), the only agent judgement is escalation, and the heavy lane
stays mandatory for any protected surface or multi-ticket effort. (Full
detail: `docs/engineering-workflow.md`.)

## Build — agents execute against the tracker

One ticket per agent session, worked in the Build read order (issue → spec →
ADRs → `CONTEXT.md` → code). Workers cite relevant ADRs, respect blocking
edges, keep diffs lean (stdlib first, test-first), and record new
hard-to-reverse decisions as ADRs — pushed immediately. Closing a ticket
requires pasted proof of its acceptance criteria. Orchestration is optional
and host-specific (single session works the frontier serially; parallel
builds use the host's mechanism — herdr panes under pi, headless workers
under Claude Code — under the host-neutral rules in the factory-orchestrator
skill: orchestrator never writes code, QC + adversarial review before
blessing, HANDOFF ping, two-failure halt). Workers end with a HANDOFF ping
to the orchestrator when orchestrated: what landed, ADRs written, followups.

## Test — one command, fail-first, protected checks

One command is the gate: `tests/validate.sh [<range>]` prints one
`ok:`/`FAIL:` line per check, then `N ok, M failed`; non-zero exit means
"not healthy." Closing a ticket pastes that run (full output + exit code,
with the ticket's range) — for a bug/defect fix, plus the fail-first pair
(red on the bad version, then green) — never an assertion; a close missing
any of the run, the acceptance output, or the pair (for fixes) is reopened. Fail-first: a bug fix pastes
the check red on the bad version, then green; a new static check is admitted
only with a witness (historic sha or one-line mutation), and
`tests/validate.sh --witness` replays them all. Protection rule: a diff that
removes, narrows, or reorders a check away from what it guards — or removes
or narrows content a negative check guards, in `tests/` or anywhere — is
rejected unless it cites the issue retiring the rule; the fixer of a
checking surface never loosens the check in the same diff. Tests check
artifacts (deterministic, offline); behavioural findings are evals and stay
in the eval ledger. CI runs the same command on every PR into `main`
(`.github/workflows/gate.yml`, check `gate`). The check list lives in the `## Commands` block of
`AGENTS.md`, its token set verified by the suite itself (prose and grouping
unverified). The orchestrator still QCs against the intent plus an
adversarial pass.

## Deploy — gated

Every diff is reviewed per `REVIEW.md` (code-review two axes + an adversary
pass on agent-produced diffs sized to the computed lane — unbounded at T2,
bounded at T1, none at T0; findings tagged by risk class, resolved or carried
with an owner — never by silence). The merge gate pastes: review resolution,
`tests/validate.sh [<range>]` (Test §1), the `--lane` and `flagged:` lines and
the adversary verdict the lane owes, the merge hold, preview proof for UI
tickets, branch-protection proof for merge-path tickets, and an `ADR:` line in
the PR body (`ADR: none` when there is no decision; check `pr-adr-line` in CI).
**Merge policy (ADR 0005):** the hold list — `tests/validate.sh`,
`.github/workflows/**`, `.githooks/**`, the files that check other files,
reported by `flagged: yes` — merges only on a named human checkoff recorded in
the thread or a recorded operator delegation (label `flagged-risk`).
Everything else, including AGENTS.md, the synced trio and ADRs, an agent may
land on green; a human reviews it after merge (`cmu` lists it as "review
owed"; a board-only `STATUS.md` commit acknowledges review of everything
merged before it; the behavior files in `docs/verify/` verify the agent side).
Branch protection is verified, not assumed: auto-merge holds only while the
CI `gate` check is required on `main`. Today it is advisory, so the pre-merge
human checkoff stays the enforcement until the operator makes it required
(#33) — a 401 is not evidence of absence, authenticate first. Hooks/CI/release
gates and irreversible ops are always human-authorized.

## Maintain — the intake point

Maintain is the intake point: retro findings, incident learnings, and
transcripts become issues and work-item intents re-entering through Plan —
findings become intents humans approve, never autonomous fixes; feedback
deposits into git, never dies in chat. Every fixed incident class becomes
text in the eval ledger (#8). Consumers owe a drift-detection rule set and
a rehearsed rollback path; automation of the stage waits on #1.

## Humans above the loop

- **Instigating**: the intent — the one artifact only humans approve. Issues
  first, one request per issue; intents live at
  `intent/<issue-number>-<slug>/intent.md`, aligned with `SYSTEM-INTENT.md`.
- **Directing**: the tracker arbitrates — labels + blocking edges decide flow.
- **Governing**: review, scope approval, proof requirements at every seam.

Non-negotiables: GitHub Issues is the tracker (no side TODO files). Blocking
edges are explicit (native dependencies or declared fallback). `ready-for-agent` is a contract. ADRs are pushed
immediately. Closing work requires pasted proof. Artifacts over conversation.

Full detail: `docs/engineering-workflow.md` in the repo.