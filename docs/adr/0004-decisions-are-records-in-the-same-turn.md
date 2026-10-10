# Decisions are records in the same turn, and intake never waits

**Issue:** #41 · **Status:** accepted (approved by the operator on #41) ·
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

**Amended from `claude-harness`.** There, settling was the record's approval,
which let an agent self-merge its own records with no merge policy behind
them. Here, approval of the decision and merge of the record are separate.

**Consequences.** The Design item "a settled decision becomes a record in the
same turn" and the Plan item "one request, one issue" state the rule only.
Records-worktree mechanics are out of scope until a ticket proposes them. The
synced trio (`docs/engineering-workflow.md`,
`plugin/skills/engineering-workflow/SKILL.md`, `README.md`) changed together
per the sync rule.

Forward reference: none; the merge policy is ADR 0005.
