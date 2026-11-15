# Decisions are records in the same turn, and intake never waits

**Issue:** #41 · **Status:** accepted (approved by the operator on #41; amended on #169 and #171) ·
**Intent:** arti-build issue #77 ("decisions become records"), narrowed by
arti-build-plugin issue #82; first landed on branch `claude-harness`.

Upstream (arti-build #77), a developer's session settled a design decision in
conversation and left it there — parked in chat, promised for a later batch
update — instead of landing it in the artifact the loop reads. The decision
was real, but nothing durable held it: no ADR, no spec edit, no ticket body
line, so the next session (or the next reviewer) had no record to read, only
a transcript to re-derive it from.

**Decision.** A settled decision — "let's go with X", "lock that in", "we
decided" — becomes a record in the same turn it is settled, before the next
question, never held for later batching. It lands by kind: a hard-to-reverse
or authority rule becomes a new ADR in `docs/adr/NNNN-slug.md`; a requirement
or design detail becomes an edit to the spec's matching section; a detail
scoped to one ticket becomes an edit to that issue's body. **Settling approves
the decision. It is NOT a merge approval — the record merges only under the
repo's merge policy** (ADR 0005). No separate sign-off on the decision is
owed beyond the Design approval gate's high-risk carve-out. Paired with this: intake never
waits — filing a new request is never gated by running workers, an open
blocker, or a foundation ticket in flight; a dependent request is filed as
its own issue with a blocking edge to the one ahead of it (mechanics:
`docs/agents/issue-tracker.md`).

**Amended 2026-11-14 (PR #169; the developer's decision on that PR).** A
developer's explicit request for a `feature` or `bug` change, in any phrasing,
is the approval to build it on a branch. A `system-change` intent (a change to
the tool's own rules) still needs an explicit "go" on the written intent. The
developer is not asked for a separate "go"; their words are saved as the
approval record automatically. Questions, thinking aloud and "don't build
yet" are not requests. High-risk work still gets one explicit yes. The merge
policy (ADR 0005) is untouched. Evidence: the eval session-chain scored 0/5
because "please update what's already there" was held for approval.

**Amended from `claude-harness`.** There, settling was the record's approval,
which let an agent self-merge its own records with no merge policy behind
them. Here, approval of the decision and merge of the record are separate.

**Amended 2026-11-14 (PR #171; the developer's decision on that PR).** A settled decision is still recorded in the same turn. There is no
per-conversation records branch or records PR, and a `system-change` intent
rides its ticket branch like any other intent. A record for a ticket goes on
that ticket's branch; any other record (an ADR, or a one-line ADR when nothing
harder is at stake) goes on its own small branch and PR, because `<base>`
refuses a direct push. The developer's checkout is never switched to write
one. What is given up is early, separate review of a system-change intent
before its work; two rules take its place: a ticket that needs that rule is
filed blocked by it, and the approval comment names the intent at a commit
SHA. Evidence: decision records cost 2.9x conventions with the records PR;
the lean build that dropped it cost 1.36x and kept the record 5/5
(`smcozart/cozysuite_review_evidence`, RESULTS.md).

**Consequences.** The Design item "a settled decision becomes a record in the
same turn" and the Plan item "one request, one issue" state the rule only.
Records-worktree mechanics: `intent-conversation` Move 2b (amendment above). The
synced trio (`docs/engineering-workflow.md`,
`plugin/skills/engineering-workflow/SKILL.md`, `README.md`) changed together
per the sync rule.

Forward reference: none; the merge policy is ADR 0005.
