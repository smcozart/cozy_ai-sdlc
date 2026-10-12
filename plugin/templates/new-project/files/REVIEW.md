# Review every diff against this policy. Tag each finding with the risk class it poses.

## Passes

Run all three on every diff — the ticket's range, stated in the review.

- **Bugs** — logic errors, broken edge cases, regressions.
- **Security** — injection, secrets, PII in logs, permissions.
- **Compliance** — the change matches its `spec.md` and this repo's records
  (`CONTEXT.md` vocabulary, ADR constraints).

## Severity

- **Important**: would break behaviour, leak data, or breach a written
  contract (the merge policy, the `ready-for-agent` contract).
- Style and naming are nits.

## Skip-list

Do not review by eye what `tests/validate.sh` enforces (the check list in
`AGENTS.md` `## Commands`). Skip `.factory/` — local state, ignored by git.

## The loop

- Every diff gets the `code-review` skill's two axes plus an `adversary`
  pass sized to the lane (`tests/validate.sh --lane <range>`): unbounded at
  T2; at T1 bounded to the diff's own claims, MED+ findings only; none at T0,
  where the gate run is the review and the close pastes `adversary: n/a — T0`.
- Authors resolve each finding by a fix commit or a carried-forward note in
  the tracker with an owner other than the author — never by silence.
- Who merges, and when: `docs/engineering-workflow.md` Deploy.
