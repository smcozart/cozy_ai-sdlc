# Review every diff against this policy. Findings are tagged with the risk class they pose (see Passes).

## Passes

Run all three on every diff — the ticket's diff range, stated explicitly in the review, the same way the Test gate requires a range ("agent-produced" means authored in an agent session). Tag each finding with the risk class it poses — Bugs, Security, or Compliance — regardless of which pass or axis surfaced it.

- **Bugs** — logic errors, broken edge cases, regressions.
- **Security** — injection, secrets, PII in logs.
- **Compliance** — the change matches its spec.md / plan.md and the repo's design principles (CONTEXT.md vocabulary, ADR constraints).

## Severity

- **Important**: would break behavior, leak data, or breach a written contract (sync rule, protection rule, `ready-for-agent` contract).
- Style and naming are nits.

## Skip-list

Do not review by eye what a check enforces mechanically:

- The exact assertion each `tests/validate.sh` check makes — the canonical set is the check list in AGENTS.md's `## Commands` block (e.g. that the synced trio changed together, the `intent/` layout, ADR numbering and references, `hooks.json` shape, skill frontmatter and byte-identical copies, the t1/t3 regression claims) — and nothing beyond it: a checked file's content is still reviewed. Future checks are auto-covered.
- `.factory/` — orchestrator-local, untracked by design.
- Generated files — none today.

## The loop

- Reviewers give reviews per this policy: the `code-review` skill's two axes plus an `adversary` pass on agent-produced diffs **sized to the computed lane** (`tests/validate.sh --lane <range>`, ADR 0003): unbounded at T2; at T1 bounded to the correctness of the diff's claims, MED+ findings only; none at T0, where the gate run is the review and the close pastes `adversary: n/a — T0`. These passes and the adversary produce the findings; every finding is tagged with its risk class from `## Passes`.
- Review timing follows the merge policy (ADR 0005). A diff on the hold list (`flagged: yes` from `tests/validate.sh --lane`: `tests/validate.sh`, `.github/workflows/**`, `.githooks/**`) is reviewed and checked off by a named human before merge. Every other diff may land on green and is reviewed after merge: `cmu` lists it as "review owed", and a board-only `STATUS.md` commit acknowledges review of everything merged before it.
- Authors resolve findings by a fix commit or an explicit carried-forward note — never by silence. A carried-forward note lives in the tracker with an owner other than the author, and is re-verified at the next operator checkpoint (the between-tickets report where the operator releases work).
