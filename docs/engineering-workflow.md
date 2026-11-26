# Engineering Workflow: Matt Pocock Skills + ADRs + Herdr Orchestration

This is the standard process, extracted from how this repo actually runs. All machines
running Claude Code or pi should follow it. Prerequisites: Matt Pocock skills installed
(`mattpocock/skills`), `gh` CLI, and for parallel builds the `herdr` CLI.

## Pipeline (in order)

```
setup (once per repo)
  → issue-first intake → intent → /to-questionnaire → /to-tickets → /triage loop
  → /implement (per ticket, test-first) → one adversary pass (ADR 0008)
  → ADRs + CONTEXT.md maintained continuously (domain-modeling)
  → /retro at milestones, /handoff at session end
```

## One-time repo setup

**`/setup-matt-pocock-skills`** — run once per repo before any other skill. Decides and
records:

- **Issue tracker**: GitHub Issues by default (remote, shared, API-addressable — fits
  fits multi-session/multi-agent work; see `docs/agents/issue-tracker.md`). Local markdown only for non-GitHub repos.
- **Triage labels**: the five canonical triage-role labels, plus `ready-for-agent`
  ("blockers resolved, acceptance criteria defined").
- **Domain docs**: `CONTEXT.md` at repo root, ADRs in `docs/adr/NNNN-slug.md`.

## Plan — issue-first intake and work-item intent

Formalized in issue [#2](https://github.com/smcozart/cozy_ai-sdlc/issues/2).

1. **Issue-first intake.** Every request — greenfield or brownfield — becomes
   a GitHub issue before any other artifact. The issue states the problem,
   desired outcome, scope, and non-goals. No side-lists in chat.
2. **One request, one issue.** A conversation containing multiple requests is
   split into separate issues (GitHub sub-issues or `Blocked by:` edges when
   they depend on each other); each gets its own intent and lifecycle. Mixing
   concerns in one issue hides scope from triage and review. Intake never
   waits (ADR 0004): a request is filed the moment it is said, even
   mid-build; a dependent request is filed as its own issue with a blocking
   edge to the one ahead of it (mechanics: `docs/agents/issue-tracker.md`),
   never held for later batching.
3. **Work-item intent.** After triage clarification, capture the agreed why in
   `intent/<issue-number>-<slug>/intent.md` (start from
   [`intent/TEMPLATE.md`](../intent/TEMPLATE.md)). The issue number is the join
   key: it ties the intent to the issue, later branch, run, PR, and pasted
   proof. The intent rides its ticket branch into the work PR.
4. **System-intent alignment.** Greenfield work starts from
   [`SYSTEM-INTENT.md`](../SYSTEM-INTENT.md); every work-item intent is checked
   against it. Conflicts either amend SYSTEM-INTENT.md deliberately or rewrite
   the intent.
5. **Approval.** Normal work (`feature`, `bug`): the developer's explicit
   request is the approval, in any phrasing, with no separate "go" (ADR
   0004). A `system-change` intent still needs an explicit "go". Their words
   are saved to the issue thread automatically and `ready-for-agent` follows.
   High-risk work (security, data loss,
   irreversible migrations, public contracts): explicit review — a designated
   human reviewer signs off in the issue before Build, and the decision gets
   an ADR.
6. **Artifact chain.** intent → ADRs / tickets → plan → code + tests →
   pasted proof. Each stage consumes the previous artifact by reference (issue
   number or path), never by copy-paste.
7. **`plan.md` is optional Build preparation.** The Plan stage produces the
   *intent*. A `plan.md` — the ticket/ADR **execution sequencing** — is
   written after Design only when a multi-ticket build has a real order or
   blocking story to record; single-ticket work skips it, and nothing in the
   suite or close proof requires it. It belongs to Build preparation, not
   Plan, and is **not** the agent's plan-before-code (that stays an
   always-kept per-session coding practice, never captured as `plan.md` — see
   Build).

Both flows share this contract: **greenfield** seeds the intent from the brief
or PRD against SYSTEM-INTENT.md; **brownfield** seeds it from the diagnosis,
retro finding, or transcript, and checks it against the same system intent.

## Design — ADRs, tickets, and the approval gate

Formalized in issue [#3](https://github.com/smcozart/cozy_ai-sdlc/issues/3);
`spec.md` retired by ADR 0008.
Design turns an approved intent into the durable artifacts the work needs —
the ADRs the design requires and ticket issues — then passes the approval
gate that moves work toward `ready-for-agent`.

1. **The intent is the design record** (ADR 0008). There is no `spec.md`:
   requirements, constraints and acceptance criteria live in
   `intent/<n>-<slug>/intent.md`; a hard-to-reverse decision lives in an
   ADR; a detail scoped to one ticket lives in that ticket's body. The issue
   body links to the intent by path. Never copy intent content into the
   issue body — reference by path only, so no stale duplicate can exist.
   The older `spec.md` files under `intent/` are records, not a contract.
2. **Intent required sections** (template:
   [`intent/TEMPLATE.md`](../intent/TEMPLATE.md)): Problem · Desired
   outcome · Scope · Non-goals · Acceptance criteria · System-intent
   alignment.
3. **Vocabulary comes from CONTEXT.md.** Intents and ticket titles name
   concepts exactly as root [`CONTEXT.md`](../CONTEXT.md) defines them; a
   term resolved during Design is added to the glossary in the same commit.
   A missing term is a signal: you're inventing language, or you found a
   real gap for `domain-modeling`.
4. **ADRs participate in Design.** A design decision that is hard to
   reverse, surprising without context, or a real trade-off gets an ADR in
   `docs/adr/NNNN-slug.md`, committed and pushed immediately. The ADR names
   the issue it decides for; the intent lists the ADRs it follows.
   Existing ADRs constrain new design: a contradiction is either surfaced
   explicitly in the intent or resolved by a new ADR that supersedes — never
   silently overridden.
5. **Intents break into vertical-slice tickets** (ADR 0002). Each ticket is a
   GitHub sub-issue of the design issue `#n` (fallback: `Part of #n` at the
   top of the child body + a task list in the parent). Each ticket is a
   tracer bullet: a narrow but complete path through every layer, demoable
   on its own, sized for one fresh context window (wide refactors go
   expand–contract instead — see `/to-tickets`). Each ticket body carries:
   what it delivers, its blocking edges (native `blocked_by` dependencies
   where available; mechanics in
   [`docs/agents/issue-tracker.md`](agents/issue-tracker.md)), runnable
   acceptance criteria, and references to the intent path and governing ADRs.
   Triage labels apply per ticket; the parent design issue closes only when
   every child is closed. The linked-issue graph IS the design.
6. **The approval gate.** Ordinary design is approved conversationally: the
   intent is posted in the issue thread and the maintainer's in-thread
   approval is the record. High-risk design (security, data loss,
   irreversible migrations, public contracts) requires an explicit human
   sign-off comment in the issue plus an ADR for the decision. The gate
   sits before labeling: tickets are cut from an intent only after it has
   passed. A ticket then earns `ready-for-agent` on the standard two
   conditions — blockers resolved + acceptance criteria defined. No label,
   no work.
7. **What Build reads, in order** (forward contract to the next stage): (1)
   `gh issue view <n> --comments` (the ticket, a child issue per ADR 0002),
   (2) follow the ticket body's intent-path reference (or its parent's
   `intent/<parent-n>-<slug>/`) to the `intent.md` for the why and the
   acceptance criteria, (3) every ADR touching the area, (4) root
   `CONTEXT.md`, (5) only then the code. A ticket whose intent or links are
   missing is bounced back to Design, not improvised around.
8. **Greenfield vs brownfield — one workflow, different seeds.** Same
   pipeline, same artifacts, same gates. Greenfield seeds the intent from the
   brief or PRD against SYSTEM-INTENT.md, and its design concerns are mostly
   new seams; brownfield seeds it from the diagnosis, retro finding, or
   transcript, and its design must first read the existing code and ADRs it
   touches, preferring existing seams over new ones. The read order above is
   identical — in brownfield, step (5) simply has more to say.
9. **A settled decision becomes a record in the same turn** (ADR 0004). When
   the developer settles something in conversation — "let's go with X",
   "lock that in", "we decided" — it lands in its durable home before the
   next question, never held in chat for later batching: a hard-to-reverse
   or authority rule becomes a new `docs/adr/NNNN-slug.md`; a requirement or
   design detail becomes an edit to the intent's matching section; a detail
   scoped to one ticket becomes an edit to that issue's body; any other
   decision becomes a one-line ADR. A file record goes on its ticket's
   branch, or on its own small branch and PR; there is no per-conversation records
   branch. Settling
   approves the decision. Settling is not a merge approval — the record
   merges only under the repo's merge policy (ADR 0005). No separate
   sign-off on the decision is owed beyond item 6's high-risk carve-out.
   Reply in one line naming the record. "Captured in this conversation
   only" and "finish mapping first, then update once" are not moves; batch
   only when asked. The `intent-conversation` skill carries the mechanics.

## Review lane — one adversary pass, one merge hold

Formalized in ADR 0008 (it supersedes the tiered lanes of ADR 0003). Every
PR takes the same path: a short `intent/<n>-<slug>/intent.md`, the gate run,
and **one read-only adversary pass** (Deploy §1). There is no lighter review
budget and no size or path tier: the tiers decided nothing (73 of 76 merged
PRs here and 25 of 25 in cozystudio were the full lane).

`tests/validate.sh --lane <range>` stays, for the **merge hold**. It prints
two lines to paste beside the gate run at close: a `range:` line with the
resolved shas, and **`flagged: yes|no`** — the one machine-readable source
for the hold: `yes` when the range touches the hold list of ADR 0005 (the
files that check other files; the list is `LANE_HOLD` in
`tests/validate.sh`), so a human merges. It reads renames as delete + add,
so moving a held file out of place is the delete it is. A range whose base
is not the merge-base with the base branch is marked **PARTIAL** and is not
valid for a close — the hold is always computed over the ticket's full
range. An empty or unreadable range exits 2 (fix the range). The hold list
is not the broader flagged-risk set in Deploy §4, which stays review
guidance.

## Build — agents execute against the tracker

Formalized across issues #2/#3; this section is the contract every host runs,
whatever the harness. The frontier is the tracker:
`gh issue list --label ready-for-agent`, blockers closed.

1. **One ticket per agent session.** A fresh session (any harness — pi, Claude
   Code, Codex) picks one `ready-for-agent` ticket, reads it in the Design §7
   order (ticket → intent → ADRs → `CONTEXT.md` → code), and works nothing else.
2. **Test-first, lean.** Red-green slices; stdlib first; shortest working diff;
   no speculative abstractions. Every test guards behavior no other test covers.
3. **ADRs during Build.** A decision that meets the ADR bar gets
   `docs/adr/NNNN-slug.md` in the same change — committed and pushed
   immediately. Workers cite the ADRs their ticket names.
4. **`plan.md` is optional Build preparation.** When a multi-ticket build has
   a real order to record, a `plan.md` written after Design sequences tickets
   and ADRs into execution order; it is an input to Build, not an artifact
   Build owes, and single-ticket work skips it. This is distinct from the
   agent's **plan-before-code** — the always-kept in-session practice of
   planning before writing code, which is never captured as `plan.md`.
5. **Proof over claim.** Closing a ticket requires running its acceptance
   criteria and pasting the commands + output into the issue. Failures reopen
   the ticket with the failing command.
6. **Bounce, don't improvise.** A ticket whose intent, ADR, or links are missing
   goes back to Design with a comment saying what's missing — never worked
   around.

**Orchestration is optional and host-specific.** A single session can work the
frontier serially. Parallel builds use whatever the host provides (herdr panes
under pi, headless workers under Claude Code, etc.) under the same
host-neutral rules — orchestrator never writes code, one ticket per worker,
QC + adversarial review before blessing, workers end with a `HANDOFF:` ping,
two consecutive QC failures halt the chain. Those rules live in the
`dispatch` skill; the hosts change, the contract doesn't.

## Test — one command, fail-first, protected checks

Formalized in issue [#9](https://github.com/smcozart/cozy_ai-sdlc/issues/9).
Build §5 stays; Test adds the repo's own standing rules to every close. The
command is the contract, not any harness hook.

1. **One command is the gate.** `tests/validate.sh [<range>]` prints one
   `ok: <check>` / `FAIL: <check> — <why>` line per check, then
   `N ok, M failed`; non-zero exit means "not healthy." Closing a ticket
   pastes that run (full output + exit code) next to the acceptance-criteria
   output, passing the ticket's range explicitly (e.g. `origin/main..HEAD`) —
   for a bug/defect fix, plus the fail-first pair (red on the bad version,
   then green). A close missing any of the run, the acceptance output, or
   the pair (for fixes) is reopened, same as a failed acceptance criterion.
2. **Fail-first.** A bug/defect fix pastes the pair: the check red on the bad
   version for the expected reason, then green on the fix. A new static check
   is admitted only with a witness — a historic sha it fails on, or a one-line
   mutation that makes it fail — pasted once when the check lands.
3. **Witnesses are runnable.** `tests/validate.sh --witness` replays every
   witness through the same check functions (bad sha / mutated tree → FAIL,
   good sha → ok). A check whose witness stops failing is a broken check.
   Needs full history (`git fetch --unshallow` on a shallow clone).
4. **Protection rule.** A diff that removes, narrows, or reorders a check
   away from the path it guards — or that removes or narrows content a
   negative check guards (an absence check passes vacuously once its target
   wording is deleted), in `tests/` or anywhere else — is rejected in review
   unless it cites the issue that retires the rule. Whoever fixes a checking
   surface does not loosen the check that measures it in the same diff.
5. **Tests are not evals.** `tests/validate.sh` checks artifacts (a file says
   X, a commit touches Y) — deterministic, offline, bash + git + python3
   stdlib. Findings with no textual footprint stay in the eval ledger (#8);
   the eval harness waits on #1. CI runs the same command over the PR
   range on every PR into `main` (`.github/workflows/gate.yml`, check
   `gate`, #33), and over `HEAD~1..HEAD` on every push to `main` (#181).

The check list lives in the `## Commands` block of `AGENTS.md`; the
`agents-commands` check verifies the token set against `--list` (prose and
grouping around the names are not verified).

## Deploy — review loop, merge gate, autonomy boundaries

Formalized in issue [#12](https://github.com/smcozart/cozy_ai-sdlc/issues/12).
Deploy is what a diff owes before it merges — the same checklist at either
seam: this repo's ticket close, or a consumer's PR.

1. **The review loop.** Every diff is reviewed against
   [`REVIEW.md`](../REVIEW.md) by one read-only `adversary` pass on every
   agent-produced diff (Review lane; ADR 0008).
   Findings are tagged by
   risk class (Bugs / Security / Compliance) regardless of which pass
   surfaced them; a finding is resolved by a fix commit or an explicit
   carried-forward note in the tracker with an owner other than the author,
   re-verified at the next operator checkpoint — never by silence. The
   review thread (closing comment or PR) is the audit record.
2. **The merge gate.** A close pastes, beside the Test gate's evidence:
   (a) review findings resolved or carried with an owner; (b) the pasted
   `tests/validate.sh [<range>]` run (Test §1); (c) the `range:` and
   `flagged:` lines of the gate run's trailer and the adversary verdict; (d) the merge hold: at `flagged: yes`
   a named human checkoff recorded in the thread (or a recorded operator
   delegation) before merge; at `flagged: no` the agent may land on green
   (table below; ADR 0005);
   (e) UI tickets only: preview proof pasted — screenshot, recording, or
   standing link (consumer obligation; this repo has no UI surface);
   (f) branch-protection proof for tickets touching the merge path, others
   mark "n/a — not a merge-path ticket".
   Merge-path = a diff at `flagged: yes` (the hold list, ADR 0005);
   everything else marks n/a.
3. **Branch protection is verified, not assumed.** Any merge-path close runs
   `gh api repos/{owner}/{repo}/branches/main/protection` and
   `gh api repos/{owner}/{repo}/rules/branches/main` and pastes both
   results: the protection fields and rules, or the recorded absence.
   Today: `main` is protected (pull request required, no force-push, no
   deletion). The `gate` check is required; the merge hold list (ADR 0005)
   is the only pre-merge human gate; everything else lands on green with
   post-hoc review (#33; ADR 0005 fails closed). An
   authentication failure (401) is not evidence of absence — authenticate
   first. No online
   check joins `tests/validate.sh` (Test §5); this proof stays manual.
4. **Autonomy boundaries.**

   | Change class | Who merges |
   |---|---|
   | Hold list — `flagged: yes` from `tests/validate.sh --lane`: the files that check other files; the list is `LANE_HOLD` in `tests/validate.sh` | A named human checkoff, recorded in the thread, after a green gate — or a recorded operator delegation. The PR carries the `flagged-risk` label |
   | Everything else, including AGENTS.md, README.md, ADRs, CONTEXT.md and the skills | Agent may land on green; the gate's pasted evidence is the record; post-hoc review follows on review paths |

   **Post-hoc review** (ADR 0005): a human reviews, after merge and against
   `REVIEW.md`, every diff that landed on green on a **review path** — the
   files that steer later agents: skills (`skills/`), `docs/adr/`, `docs/engineering-workflow.md`, `AGENTS.md`, `REVIEW.md` and `SYSTEM-INTENT.md`, each at any depth. `cmu` lists it as
   "review owed". The developer says in chat that they reviewed; the agent
   appends `reviewed through <40-hex sha> on <date>` to `STATUS.md` in a
   commit that changes only that file (`intent-conversation` Move 5); a line added by any other commit acknowledges
   nothing. It covers exactly the first-parent history of the base branch up
   to that sha, never what merged while the line was in review. The behavior files in `docs/verify/` verify the agent side.
   The former flagged-risk set (suite-checked surfaces, `docs/agents/`,
   security/trust boundaries) is review guidance, not a hold. Auto-merge
   holds only while `gate` is a required check on `main`; otherwise every
   merge takes the pre-merge checkoff (§3). Hooks/CI/release gates and
   irreversible ops are always human-authorized. Only an operator decision,
   recorded as an ADR 0005 amendment, adds a pre-merge checkoff or drops the
   post-hoc review.

## Maintain — closing the loop

Maintain is the intake point: retro findings, incident-class learnings,
and session transcripts get structured into issues and work-item intents
and re-enter through Plan — findings become intents humans approve, never
autonomous fixes. Feedback deposits into git (issues, ADRs, workflow
doc, CONTEXT.md), never dies in chat; the loop gets shorter and more
reliable each revolution.

**Eval-on-incident:** every fixed incident class becomes eval material
in the eval ledger (#8) — the Test §5 boundary; the ledger is a
document, and the only permitted writes are text (no runner, scanner, or
automation lands here until #1 unfreezes). Dismissed findings stay on
record with a reason.

**Consumer obligations (this repo has no production runtime — contract
text only, same shape as preview proof):** a consumer of the Harness
owes a drift-detection rule set for the metrics it runs the loop on
(version-controlled config; detection deterministic, no model involved),
and a rehearsed rollback path for what the loop may trigger at its
highest tier. Both arrive as findings through the intake point, and
fixed incident classes become eval material per the rule above.

Automation of this stage — triggers, hooks, monitoring bands, rollback
tooling — waits on #1.

## Stage-by-stage map

| Stage | Skill | When / where |
|---|---|---|
| Capture the intent | issue + `intent/<n>-<slug>/intent.md` | First, right after the issue exists (see **Plan — issue-first intake** above). |
| Elicit requirements | `/to-questionnaire` | New feature with unknowns. Converts vague asks into answerable questions. |
| Break into tickets | `/to-tickets` | After the intent is approved; never `/to-spec` — there is no `spec.md` (ADR 0008). Do NOT apply `ready-for-agent` before the approval gate. Tracer-bullet vertical slices; blocking edges declared per ticket (GitHub native blocking links). Never horizontal layers. |
| Groom the queue | `/triage` | Continuous. State machine of triage roles → issues end as agent-ready briefs labeled `ready-for-agent`. AI-generated comments carry the AI-triage disclaimer. |
| Stress-test thinking | `/grilling` (or `/grill-me`, `/grill-with-docs`) | Before accepting an intent, an architecture, or an agent's plan. Cheap insurance; use liberally at decision points. |
| Implement | `/implement` | Per ticket, one ticket per session. Test-first (red-green slices). Lean: stdlib first, shortest working diff. |
| Test discipline | `/tdd` | Default mode inside implement. Every test justifies itself — guards behavior no other test covers. |
| Debugging | `/diagnosing-bugs` | When something is broken/slow, not during planned work. |
| Review | `REVIEW.md` | After each diff (or each batch): the one adversary pass below (ADR 0008); policy per REVIEW.md. |
| Adversarial review | `adversary` subagent (pi) | On every agent-produced diff, one read-only pass (ADR 0008). Breaks the author-boss bias loop. Claude equivalent: the same one pass, read-only, with "assume this is wrong" instructions. |
| Record decisions | `domain-modeling` | ADR bar: hard to reverse, surprising without context, or a real trade-off. One paragraph, `docs/adr/NNNN-slug.md`, **commit and push** — an unpushed ADR is invisible. Visible in code ⇒ no ADR. |
| Shared vocabulary | `CONTEXT.md` via `domain-modeling` | Update when terminology shifts; consumers read it before issues. |
| Milestone retro | `/retro` | At milestones or when a failure pattern repeats. Feed findings into ADRs or process edits. |
| Session end | `/handoff` | Compact conversation → handoff doc for the next session. References artifacts by path; never duplicates them. |
| Session pickup | `/cmu` | Resuming after time away, or after unattended dispatch. Reads the tracker and git for a grounded delta since an anchor — landed, in flight, needs you, next. Reports only; never dispatches or writes. |

## Orchestration layer (multi-agent builds)

**The `dispatch` skill + a host worker mechanism** — when tickets are
parallelizable and you want workers, not a single session. The skill's rules
are host-neutral; herdr is the first host it detects (its herdr row), and the
other hosts keep the same contract. Key rules (full detail in the skill):

1. Orchestrator never writes code; it dispatches, watches, and runs QC itself.
2. One ticket per worker session, fresh pane per ticket (`herdr tab create` →
   `herdr agent start --kind <worker kind from AGENTS.md, default claude>` →
   the herdr brief in the skill).
3. Orchestrator pre-answers the 2–3 ticket ambiguities **in the worker prompt**.
4. GitHub is the claim; the orchestrator's terminal proves the hold and the review; CI's `gate` proves the suite (ADR 0007).
5. Workers end with a `HANDOFF:` direct ping to the orchestrator pane before idling.
6. Two consecutive QC failures anywhere → halt the chain, revisit the prompt/design
   with the operator.
7. No load-bearing sessions: any pane can die and work resumes from GitHub + pushed
   commits — the tracker and the remote are the only state.

The full skill text lives at `plugin/skills/dispatch/SKILL.md`; Claude Code
loads it from the plugin. pi loads the skills in `.agents/skills/` (in a
trusted project), and `dispatch` is not one of them, so a pi orchestrator
follows `dispatch`'s herdr row by hand.

## Non-negotiables (the parts that make it work)

1. **GitHub Issues is the tracker.** Issue numbers are the join key between sessions,
   agents, and machines. No side-lists in chat, no parallel TODO files.
2. **Blocking edges in the tracker**, not in anyone's head. Dispatch order reads off
   the graph.
3. **`ready-for-agent` is a contract**: blockers resolved + acceptance criteria defined.
   Agents never pick up unlabeled work.
4. **ADRs are pushed immediately.** Decisions live in `docs/adr/`, not in session memory.
5. **Proof over claim.** Whoever closes work runs the verification commands and pastes
   the output into the issue.
6. **Artifacts over conversation.** Intents, ADRs, and issues are durable; chat is not.

## Do we need a documentation skill on top of this?

No. Documentation here already has three owners, and a fourth would overlap all of them:

- `domain-modeling` → CONTEXT.md + ADRs (the "why" and the vocabulary)
- `intent.md` → the "what we're building" (ADR 0008)
- `/handoff` → session continuity

What's worth adding instead is a lightweight rule, now captured above: **user-facing docs
(`README`, `docs/`) get updated in the same PR as the change they describe**, same bar as
tests. If docs debt ever becomes real, revisit — don't pre-build a skill for it.
