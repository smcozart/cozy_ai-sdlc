# Review every diff against this policy. Findings are tagged with the risk class they pose (see Passes).

## Passes

Run all three on every diff — the ticket's diff range, stated explicitly in the review, the same way the Test gate requires a range ("agent-produced" means authored in an agent session). Tag each finding with the risk class it poses — Bugs, Security, or Compliance — regardless of which pass surfaced it.

- **Bugs** — logic errors, broken edge cases, regressions.
- **Security** — injection, secrets, PII in logs.
- **Compliance** — the change matches its intent.md / plan.md and the repo's design principles (CONTEXT.md vocabulary, ADR constraints).

## Severity

- **Important**: would break behavior, leak data, or breach a written contract (merge hold, protection rule, `ready-for-agent` contract).
- Style and naming are nits.

## Skip-list

Do not review by eye what a check enforces mechanically:

- The exact assertion each `tests/validate.sh` check makes — the canonical set is the check list in AGENTS.md's `## Commands` block (e.g. the `intent/` layout, ADR numbering and references, skill frontmatter and skill links) — and nothing beyond it: a checked file's content is still reviewed. Future checks are auto-covered.
- `.factory/` — orchestrator-local, untracked by design.
- Generated files — none today.

## The loop

- Reviewers give reviews per this policy: one read-only `adversary` pass on every agent-produced diff (ADR 0008). That pass produces the findings; every finding is tagged with its risk class from `## Passes`.
- Review timing follows the merge policy (ADR 0005). A diff on the hold list — the files that check other files; the list is `LANE_HOLD` in `tests/validate.sh`; `flagged: yes` in the gate run's trailer — is reviewed and checked off by a named human before merge. Every other diff may land on green; one on a review path (skills (`skills/`), `docs/adr/`, `docs/engineering-workflow.md`, `AGENTS.md`, `REVIEW.md` and `SYSTEM-INTENT.md`, each at any depth) is reviewed after merge: `cmu` lists it as "review owed", the developer says in chat that they reviewed, and the agent appends `reviewed through <40-hex sha> on <date>` to `STATUS.md` in a commit that changes only that file; a line added by any other commit acknowledges nothing. It covers exactly the first-parent history of the base branch up to that sha, never what merged while the line was in review.
- Authors resolve findings by a fix commit or an explicit carried-forward note — never by silence. A carried-forward note lives in the tracker with an owner other than the author, and is re-verified at the next operator checkpoint (the between-tickets report where the operator releases work).
