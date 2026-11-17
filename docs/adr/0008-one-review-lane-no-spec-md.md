# One review lane, and no spec.md

**Issue:** #181 · **Status:** accepted (approved by the operator on #181,
2026-11-17) · **Intent:** `intent/181-round2-gate-cuts/intent.md`;
supersedes ADR 0001 and ADR 0003.

ADR 0003 made review effort a computed lane of three tiers: trivial (no
adversary pass), light (one bounded pass) and heavy (the full loop). ADR 0001 put a `spec.md` next to every
intent. Measured on 2026-11-15 and 2026-11-16, neither decided anything:

- Merged PR bodies show 73 heavy, 3 light and 0 trivial here, and 25 of 25
  heavy in cozystudio. The tier code was about 60 lines of `tests/validate.sh` and
  about 37 of its 101 witness rows.
- `spec.md`: 0 in cozystudio's 28 intents, 5 here, the last added
  2026-09-13.

**Decision.**

- **One review lane.** Every PR gets the gate run and one read-only
  adversary pass. There are no tiers and no lighter review budget in the
  gate, the skills or the docs.
- **The merge hold is unchanged.** `tests/validate.sh --lane [<range>]`
  stays. It prints a `range:` line (the resolved shas, PARTIAL when the
  range is not the ticket's full range) and the `flagged: yes|no` line,
  which reads `LANE_HOLD` (ADR 0005) with the same meaning and output as
  before. An empty or unreadable range exits 2.
- **No spec.md.** The work-item intent is the design record. A
  hard-to-reverse decision goes in an ADR, and a detail for one ticket goes
  in that ticket's body. `intent/TEMPLATE-spec.md` is deleted here and in
  the scaffold template, and `intent-layout` no longer reads `spec.md`. The
  five existing `spec.md` files stay as records.

**Rejected.** *Keep the tiers for a future small-change flow*: 3 of 76
merged PRs here used the light tier and none the trivial tier; a tier can come back by a new ADR with
evidence. *Keep `spec.md` optional*: an optional template still asks every
author to decide; nothing used it for two months.

**Consequences.** The light-lane allow-list, the size caps, the light-tier floor,
the version-only floor (#135) and the `no-ADR`/`not-speculative` close
clauses are gone with their witness rows. ADR 0007's base-lane step now
reads only the `flagged:` line, and its limit on the light-set paths no
longer applies. The same PR removes four checks that decided nothing:
`dispatch-hold` and `herdr-retire` (one fixed sentence each, 0 real FAILs),
and `sync-rule` and `stage-parity` with the README stage list they guarded
(36 commits paid a forced README edit), plus the `.githooks/pre-commit`
copy of the sync rule. The root gate now also runs on `push` to `main`.
The way back is the tag `golden-main-1.9.0-2026-11-16`.
