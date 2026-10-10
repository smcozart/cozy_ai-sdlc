# The Harness

The Harness is an AI-native software development process: humans stay above the
loop (instigating, directing, governing) while agents take the center. This
file is the shared vocabulary; every issue, spec, and ADR uses these terms.

## Language

**Harness**:
The process itself — the six-phase loop (Plan → Design → Build → Test → Deploy
→ Maintain) and its contracts — as packaged in this repo. Not any one tool.
_Avoid_: framework, platform, pipeline (the pipeline is only the phase order)

**intent**:
The written, human-approved "why" behind a unit of work. Two levels exist:
SYSTEM-INTENT and work-item intent. No approved intent, no work.
_Avoid_: ticket description, prompt, requirements doc

**work-item intent**:
The intent for one issue, at `intent/<issue-number>-<slug>/intent.md`. States
problem, desired outcome, scope, non-goals, acceptance criteria.
_Avoid_: brief, story, epic

**SYSTEM-INTENT**:
The system's enduring purpose at repo root (`SYSTEM-INTENT.md`). Every
work-item intent is checked against it; conflicts amend it or rewrite the
work-item intent.
_Avoid_: vision doc, charter

**tracker**:
GitHub Issues — the system of record for all work. The issue number is the
**join key** tying together intent, spec, branch, PR, run, and pasted proof.
For ticketed work: branch, PR, and proof join on the ticket (child) issue
number; intent and spec join on the parent design issue number.
_Avoid_: backlog, TODO list, board

**spec.md**:
The Design artifact for one work item, at
`intent/<issue-number>-<slug>/spec.md` (sibling of the intent). States
requirements, design concerns, constraints, and open questions. Linked by
issue number, never copied into the issue body.
_Avoid_: design doc, RFC, plan

**plan.md**:
An optional execution sequencing for Build (ticket order against blocking
edges), written after Design only when a multi-ticket build has a real order
to record; single-ticket work skips it. Belongs to Build preparation, never
to Plan, and is not the agent's per-session plan-before-code.
_Avoid_: spec, intent, plan-before-code

**ADR**:
Architecture decision record in `docs/adr/NNNN-slug.md`. Written only when a
decision is hard to reverse, surprising without context, or a real
trade-off; pushed immediately.
_Avoid_: decision log entry, meeting note

**Design**:
The phase that turns an approved intent into a spec, ADRs, and ticketed
issues. Ends at the approval gate.
_Avoid_: planning (Plan is the intake phase), architecture (only part of it)

**Build**:
The phase where agents execute one ticket per session against the tracker,
test-first, citing ADRs.
_Avoid_: implementation (too loose — Build includes its proof obligations)

**check**:
One shell function in `tests/validate.sh` that prints exactly one
`ok: <name>` or `FAIL: <name> — <why>` line. Asserts external behaviour of an
artifact (a file says X, a commit touches Y), never the script's internals.
Admitted only with a witness.
_Avoid_: test case, assertion, lint

**witness**:
The recorded fail-first proof for a check: a historic commit sha it fails on,
or a one-line mutation that makes it fail. `tests/validate.sh --witness`
replays them all; a witness that stops failing means the check is broken.
_Avoid_: fixture, snapshot, example

**light lane**:
The thinner front end for a small, low-risk change: a short `intent.md`
(problem, one-line outcome, scope, acceptance) with no `spec.md` and no
`plan.md`. The tail is unchanged — same `ready-for-agent` contract, same
pasted `tests/validate.sh` proof, same merge policy (ADR 0005); the lane
never decides who merges. A defined lane, not a
loophole; the lane is computed, not judged — `tests/validate.sh --lane`
prints T0 or T1 for it, T2 for the heavy lane (ADR 0003; light-lane section of
`docs/engineering-workflow.md`).
_Avoid_: fast track, bypass, shortcut

**gate**:
A recorded human decision that lets work cross a phase boundary. The Design
gate is approval of the spec; the Test gate is the pasted `tests/validate.sh`
run (exit 0, ticket range) beside the pasted acceptance-criteria output.
Triage is not a gate — it is a label state machine that ends at
`ready-for-agent`. Merge is a human gate only for the hold list
(`flagged: yes`; ADR 0005); every other diff lands on a green `gate` check
and is reviewed after merge.
_Avoid_: sign-off (only the high-risk variant), approval (the act, not the
record)

**merge gate**:
The checklist a diff owes before it merges, pasted at the seam (ticket close
here, PR for consumers): review findings resolved or carried with an owner,
the pasted `tests/validate.sh [<range>]` run, the adversary verdict, the
merge hold (a named human checkoff when `flagged: yes`, ADR 0005), preview
proof for UI tickets, branch-protection proof for merge-path tickets, and an
`ADR:` line in the PR body.
_Avoid_: approval (the human checkoff is one item of the gate, not the
whole), CI gate (the `gate` check runs the suite on PRs — one item
of the merge gate, not the whole)

**merge-path**:
A diff touching `tests/validate.sh`, `.github/**`, the synced trio, or
AGENTS.md — the surfaces that enforce the merge gate itself. Only these owe
the gate's branch-protection proof; every other close marks it "n/a — not a
merge-path ticket".
_Avoid_: merge diff (any diff), gate surface (the file, not the change)

**preview proof**:
The visual-change evidence pasted at close of a UI ticket — a screenshot, a
recording, or a standing link to the running preview. A consumer obligation;
this repo has no UI surface, so the contract text only defines it.
_Avoid_: demo (unrecorded), example artifact

**intake point**:
The Maintain seam where retro findings, incident-class learnings, and
session transcripts are structured into issues and work-item intents and
re-enter through Plan. Findings become intents humans approve — never
autonomous fixes.
_Avoid_: feedback loop (vague), incident process (reactive connotation)

**eval ledger**:
The corpus of prompt+check pairs for behaviors with no textual footprint
for the suite to grep, tracked in issue #8. The ledger is a document;
writes are text only until the eval harness exists (#1). Fixed incident
classes land here per the Maintain section's eval-on-incident rule.
_Avoid_: eval suite (nothing runs yet), regression tests (those are
checks)

**behavior file**:
An authored run for one ledger behavior, at `docs/verify/<behavior>.md`:
prompt, expected observations, pass bar, run mechanics. Run only at an
adoption PR or an incident-fix close (`docs/verify/README.md`).
_Avoid_: eval (no harness runs it), test (tests are checks)
