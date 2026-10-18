# Auto-merge on green; only the files that check other files hold

**Issue:** #39 · **Status:** accepted (approved by the operator on #39,
2026-10-02; hold list amended by the operator on #128, 2026-10-18,
to add the consumer gate; amended on #132, 2026-10-18, to keep the
list in one place) · **Intent:** the N-package, pi session 2026-09-28 (items 2, 3,
5, 8, 10).

Deploy §4 required a human checkoff, recorded in the thread, before any diff
on a flagged-risk surface merged. In practice it did not hold: six merges
into `claude-harness` (#28, #29, #30, #36, #37, #38) and three direct pushes
(`bf6cad5`, `03f53d2`, `7ae706b`) landed with no recorded checkoff, and the
`dispatch` hold keyed on a `flagged-risk` label that did not exist, so the
rule failed open. The operator prefers auto-merge on green and treats a
pre-merge checkoff on every surface as a rubber stamp.

**Decision.** Auto-merge on green is written policy.

- **Hold list (a human merges):** the files that check other files. The
  one list is `LANE_HOLD` in `tests/validate.sh`.
  A PR may not weaken its own gate and merge itself. The
  `flagged:` line of `tests/validate.sh --lane <range>` (ADR 0003) reads
  that list: `flagged: yes` means held. A held diff merges only after a
  named human checkoff recorded in the thread, or a recorded operator
  delegation. The tracker marks it with
  the `flagged-risk` label.
- **Post-hoc review list (an agent may land on green):** everything else,
  including `AGENTS.md`, the synced trio, ADRs, `CONTEXT.md` and the skills.
  It lands when the `gate` check is green and the merge-gate proof is
  pasted. A human reviews it after merge: `cmu` lists it as "review owed",
  and a board-only `STATUS.md` commit (one that changes only `STATUS.md`)
  acknowledges review of everything merged before it. A `STATUS.md` change
  inside a larger diff acknowledges nothing. The behavior files in
  `docs/verify/` verify the agent side of this contract.
- **ADRs stay required:** every PR body carries an `ADR:` line — the ADR
  ids the PR records or cites, or `ADR: none`. The gate check
  `pr-adr-line` fails a body without it. Presence only; review judges the
  content.
- **Fails closed:** auto-merge on green holds only while `gate` is a
  required status check on `main`. While it is not required, or when it is
  removed or bypassed, every merge reverts to the pre-merge human checkoff
  until the check is restored.
- **Two prohibitions:** no agent adds a pre-merge checkoff, and no agent
  drops the post-hoc review list or the ADR rule. Only an operator decision,
  recorded as an amendment to this ADR, changes either.

**Amended on #132 (2026-10-18).** Before, the paths of the hold list were
written out here and in about ten other documents, and the script was the
judge when they differed; one change to the list touched 12 files (#131).
Now `LANE_HOLD` in `tests/validate.sh` is the only list. This ADR and the
other documents state the policy — the files that check other files hold —
and point to `LANE_HOLD`; they do not copy the paths. A change to the list is
a change to the script, so it is itself held. The decision is unchanged.

**Rejected.** *Keep the checkoff on every flagged-risk surface*: it did not
hold in practice and it fails open. *Hold the broad flagged-risk set*
(suite-checked surfaces, `docs/adr/**`, `plugin/**`): the gate already
checks those files; only the files that are the gate can disable it.

**Consequences.** The broader flagged-risk set in Deploy §4 is now review
guidance, not a merge rule. ADR 0003's T0 "human checkoff" is the post-hoc
review for an unheld diff. One GitHub identity merges, so GitHub cannot
enforce the hold; the orchestrator skills state it (`factory-orchestrator`
here, and `dispatch` once its hold fix (#42) is adopted into `main`
(#35)). Tighter control for production systems is a later operator decision
under the prohibitions above. Deploy §2(d)/§4 in the synced trio, `REVIEW.md`,
`CONTEXT.md` and `STATUS.md` changed in the same commit.
