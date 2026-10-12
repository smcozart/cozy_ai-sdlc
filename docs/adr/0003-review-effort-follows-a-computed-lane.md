# Review effort follows a computed lane, and the lane is computed by the gate

**Issue:** #40 · **Status:** accepted (approved on #39, the ADR 0005 package) · **Intent:** the arti-agent-platform retro `.factory/retro-scaffold-speed.md` (2026-09-15); first landed on branch `claude-harness`.

The adversary pass was mandatory on every agent-produced diff, and the light
lane (#24) was a nine-clause predicate an agent evaluated by hand. Together
those produced the cost the platform measured on 2026-09-14/15: a two-file,
+10/−2 board PR (#88 there) drew a full adversary report roughly fifty times
its diff, half of whose findings were copy-edits; and because no one trusted
the hand-evaluated lane, the safe default was always the full pass. Nothing
in the loop tiered verification to the change.

**Decision.** Review effort is a function of a **lane**, and the lane is
**computed by the Test gate**, not judged. `tests/validate.sh --lane <range>`
classifies the diff from what git can see — file count, paths against an
**allow-list** of light paths, changed lines, deletes, binaries, symlinks (never
followed), instruction files in any case — and prints one `lane:` line, with resolved shas, pasted beside the
gate run (the default gate run prints it too, over the same range). **T0**
(≤2 docs files, all in the light set, none on the T1 floor): the gate run and
the human checkoff, no adversary pass. **T1** (≤2 files, ≤60 lines, all in
the light set — or any file on the T1 floor: `STATUS.md`, the first file a
session reads; `docs/training/`, what a new human runs verbatim): one bounded
adversary pass, the diff's claims only, MED+ findings. **T2** (everything
else): the full loop as before. Unknown is heavy: a path the repo has not
grown yet, a nested `CLAUDE.md`, an `.mcp.json`, a rename out of place (read
as delete + add) all classify T2 without anyone remembering to extend a
regex. Two clauses git cannot see stay with the agent and are filled in at
close — `no-ADR=<y/n> not-speculative=<y/n>` — and **escalation is the only
direction**: an agent may raise a computed lane, never lower it. Consumers
extend the light set with the paths they will review on a bounded budget; a
verbatim copy is safe. A repo without `--lane`, or a PARTIAL range, is T2.
The same run prints a second line, `flagged: yes|no`: yes when the range
touches the **merge hold list** of ADR 0005 — `tests/validate.sh`,
`.github/workflows/**`, `.githooks/**`, the files that enforce the gate — so
a human merges it. That line is the one machine-readable source for the hold;
the broader flagged-risk set in Deploy §4 stays review guidance, not the hold.
The classifier is a mode, not a check — it never turns a line red and is not
in `--list` — but it carries a witness per decision branch and per known
evasion in `--witness`, because a wrong lane is a wrong review budget.

**Rejected.** *Keep "adversary on everything"*: correct when it caught 13
defects in a two-file skill PR, but it cannot distinguish that PR from a typo
fix, and the cost grows with every parallel worker. *Let the agent pick the
tier*: that is the predicate this replaces; an untrusted judgement produces
the full pass by default. *`merge=union` / skip review for docs*: docs here
are executable — a SKILL.md tells agents what to run — which is exactly why
the allow-list, not the file extension, decides T2. *A deny-list of protected
paths* (the first cut, 2026-09-15): the adversary showed a rename of
`REVIEW.md`, a nested `handoffs/CLAUDE.md` and a new `.mcp.json` all
classifying light; a deny-list is unsafe by omission, an allow-list is safe.

**Consequences.** T0 closes with no adversary artifact at all; that is
deliberate, the `lane:` line is the record of why, and the human checkoff
stays on T0 so an agent's diff is never the last pair of eyes on itself. The thresholds (2
files, 60 lines) are starting values, changed by amending this ADR with the
evidence. The synced trio, `REVIEW.md` and `AGENTS.md ## Commands` changed in
the same commit; a consumer rule that mandates an adversary pass on every
diff follows as that consumer's own change and becomes "at T2, bounded at T1".
