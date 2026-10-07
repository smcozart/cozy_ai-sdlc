# Verification & Gate Leanness — Plan (draft, pre-issue)

**Status:** draft for fresh-session vetting. Not yet an issue.
**Base anchor:** `main` @ `ac08350` (tag `golden-v1-harness-main`).
**Branch:** `plan/verification-leanness` (worktree `~/dev/cozyharness-verif`).
**Author:** planning session in pi pane `w1:p2Y`, 2026-10-05.

This document exists to (a) let a later session recall the plan without rereading
a long conversation, and (b) be **vetted by a fresh Claude session** before any
of it becomes an issue, spec, or code. It is a proposal, not a live board and
not the tracker.

---

## 0. Operator framing — the constraints any change must satisfy

These are the rules the operator set. Any component, skill, script, check, hook,
gate, ADR, or doc proposed here must clear them:

1. **Everything must earn its place.** If it cannot be justified by a concrete,
   named failure it prevents (or a concrete capability it adds), it does not go
   in — and existing items that cannot justify themselves become candidates for
   removal.
2. **Changes must increase speed, accuracy, or reliability.** State which one,
   and how it is measured or observed. "More process" is not a benefit.
3. **Keep it lean.** Prefer subtraction to addition; prefer one authoritative
   mechanism to several partial ones; no gates without cause; anything expensive
   stays off the critical path.
4. The operator is **happy with the current AI-SDLC**; this is improvement, not
   replacement. Do not redesign what already works.

---

## 1. What the AI-SDLC is today (current behavior, for context)

**Shape.** An AI-native software-development process packaged as a repo:
six phases — Plan → Design → Build → Test → Deploy → Maintain. Humans stay above
the loop (instigate, direct, govern); agents take the center. GitHub Issues is
the system of record; the issue number is the join key across intent, spec,
branch, PR, run, and pasted proof.

**Artifacts.** `SYSTEM-INTENT.md` (enduring why), `CONTEXT.md` (vocabulary),
`intent/<n>-<slug>/intent.md` + `spec.md`, `docs/adr/NNNN-*.md`, the tracker,
and pasted proof at close.

**Hosts.** pi is the canonical, host-neutral baseline. Claude Code rides the
`claude-harness` branch (skills `cmu`, `dispatch`, `intent-conversation`; ADRs
0003/0004) and ships as a plugin (`engineering-workflow--v1.4.x` tags).

**Branch topology at planning time.**
- `main` @ `ac08350` — golden baseline (`golden-v1-harness-main`). Public repo.
- `claude-harness` @ `5af43f5`/later — main + 24 commits (skills, ADR 0003 lane,
  ADR 0004 records). Consumed by another tool via the `engineering-workflow--v1.4.x`
  plugin tags — **must not be touched or retagged**.
- `cozyharness_full_workflow` @ `c98c18d` — the new-project route (#46–#52),
  in flight in the shared checkout `~/dev/cozyharness`.

**The four enforcement layers, most to least codified:**
| Layer | What it is | State |
|---|---|---|
| Suite | `tests/validate.sh` — 14 checks (9 static + 5 regression), 35 live fail-first witnesses replayed by `--witness`. Offline, no deps, **0.4–0.8 s**. | Built, green, honest |
| Git seam | `.githooks/pre-commit` (staged sync-rule mirror) + `pre-push` (`validate.sh` over `origin/main..HEAD`), installed by `bootstrap.sh` via `core.hooksPath`. | Local, bypassable, not the floor |
| Advisory host hooks | `plugin/hooks/hooks.json` — reminders that `exit 0`. | Claude-only, never blocks |
| Agent judgment | workflow skill, `factory-orchestrator`, `REVIEW.md`, mandatory adversary pass. | Prose + discipline |

**Auto-merge, precisely.** GitHub auto-merge is **off** (`allow_auto_merge:false`;
no PR has used `autoMergeRequest`). Rulesets protect `main`/`cozyharness_full_workflow`/
`claude-harness` (deletion, non-fast-forward, PR with 0 approvals) but **no ruleset
has required status checks**. On `claude-harness`, the `dispatch` skill's
orchestrator merges via `gh pr merge` after its own QC; its human hold keys on a
`flagged-risk` label that **does not exist**, so it fails open. `cmu` supplies
post-hoc "review owed" by reading the repo workflow doc's path list. **#39** is the
open issue that would make this real policy (ADR 0005). **#33** is the open issue
to run the gate on PRs and make it a required check.

**Tracker state relevant here:** #1 (hooks/enforcement umbrella, `needs-triage`),
#8 (eval corpus / ledger), #33 (CI gate), #34 (skill-copies loop), #39 (merge
policy), #40 (computed lane + `flagged:`), #41 (records ADR), #42 (skill fixes),
#45/#23 (pre-push defects), #35 (selective adoption from claude-harness).
`STATUS.md` is stale (dated 2026-09-13; silent on #33–#52).

**Known gaps this plan touches.**
- The suite is honest (no tautological green) but **partial in places**: e.g.
  `skill-copies` covers 2 of 5 skills; `adr-refs` misses short-form refs;
  `hooks-json` accepts empty hook arrays; `sync-rule` is vacuous when the trio
  isn't touched.
- `REVIEW.md` says "do not review by eye what a check enforces mechanically," so
  a partial check silently licenses skipping the uncovered part.
- Verification grows by **incident → pinned sentence**, which is unbounded and
  brittle (the 3 prose-pin checks below are the clearest examples).
- Behaviors with **no textual footprint** live in #8, which is a flat ledger with
  no shape and no maintenance loop, "until the eval harness exists (#1)".

---

## 2. The plan

Each item states what it is, why it earns its place, which of
speed/accuracy/reliability it buys, and what it costs. Items are ordered so the
cheap, reversible ones come first. **Nothing lands on `main` until vetted and
approved; work rides a branch off the golden anchor.**

### A. Verification as a maintained behavior map (reshape #8)

**What.** Turn #8 from a flat ledger into a **behavior map**: one short file per
agent-behavior area (e.g. `close-without-proof`, `dispatch-hold`,
`intent-conversation`, `cmu-pickup`, `merge-policy`), each with fixed sections —
*what it is / how a session reaches it / how to drive it / what proves it /
gotchas* — plus a README sweep order. A maintenance pass reconciles the map
against reality and ships at most one PR of proven corrections, stated as
`clean` / `changed` / `blocked`.

**Why it earns its place.** It is the home for behaviors greps cannot cover
(does a session actually *follow* the workflow?), and it is the mechanism that
lets the suite *stop growing*: new incident learning goes to a prunable map
instead of a new forever-grep.

**Buys:** accuracy (real behavior verified, not prose pinned) + reliability
(coverage is total at the *feature* level rather than the *sentence* level).

**Cost / risk.** The maintenance cadence must be codified and actually run — a
stale map is worse than none. Trigger at milestones/retro (Maintain stage).
Needs a decision: reshape #8 in place vs. a new issue that transforms it.

### B. One authoritative CI gate (#33)

**What.** Add `.github/workflows/gate.yml` running `validate.sh` over the PR
range, then (after a short advisory trial) add the check to the `main` ruleset as
**required**. Keep the per-PR job dependency-free and sub-minute; `--witness`
stays nightly / path-filtered, off the critical path.

**Why it earns its place.** It is the **only** authoritative, unbypassable floor.
Everything else is local, optional, or advisory. It is why "green" can be trusted.

**Buys:** reliability. The gate is already 0.4 s and needs nothing installed; CI
adds a bounded ~30–60 s async wait per PR, and the pre-push hook means CI usually
*confirms* rather than *discovers*.

**Cost / risk.** One workflow file + one ruleset edit (preserve existing rules).
No path filters (the gate is sub-second; filtering adds config for nothing).
Verify interaction with the ruleset's `require_extra_approval_for_unattributed_changes`.

### C. Reduce by substitution — graduate behavior-proxy checks

**What.** Of the 14 checks, classify each as *artifact-protecting* (keep) or a
*behavior-proxy* (a grep that pins a sentence whose meaning is a behavior).
Graduate the proxies to map recipes, then retire the grep once the recipe covers
it, citing the retiring issue (Test §4 protection rule). Candidates:

- `t1-trust-wording` (pins a host factual claim)
- `t3-label-drift` (pins a sentence)
- `t3-precedence` (pins a literal phrase)

Keep all artifact/join-key checks (`intent-layout`, `adr-numbering`, `adr-refs`,
`skill-frontmatter`, `agents-commands`, `stage-parity`, `sync-rule`) and the
mechanical `t1-log-clobber` / `t1-spawn-session`.

**Why it earns its place.** It is the *subtraction* half of the plan: the
verification route should make the system smaller, not larger. The proxies fail
on rewording, not behavior, and train people to ignore red.

**Buys:** reliability (fewer brittle checks) + accuracy (behavior verified) at
lower maintenance cost.

**Also: one-in-one-out rule.** Going forward, a new *behavior* goes to the map;
adding a suite check requires a new *artifact* rule or a witness proving the map
cannot cover it. This caps suite growth.

### D. Remove duplication a check exists to guard (verify symlinks)

**What.** `skill-copies` (and #34) exist only because `plugin/skills/` and
`.claude/skills/` are byte-identical copies. If Claude Code resolves symlinks,
make `.claude/skills` a symlink to `plugin/skills` — removing the copies, the
check, and the collision class.

**Why it earns its place.** Deleting duplication deletes the check that guards
it; this is the largest available reduction in surface.

**Buys:** speed (less to maintain) + reliability (no drift possible).

**Cost / risk.** Must be **verified** against Claude Code first; if symlinks are
not resolved, drop the idea entirely (do not keep it as speculative work).

### E. Merge authority made real (#39), with #42 first

**What.** Adopt ADR 0005 as the merge policy: a **narrow** held-path list
(`tests/`, `.github/**`, `.githooks/**`, the synced trio, `AGENTS.md` — the files
that enforce the gate), everything else green⇒merge, with post-hoc review owed
surfaced by `cmu`. Requires #42 (fix `dispatch`'s fail-open hold and stale refs)
and a pi-side review-owed surface before main relies on it.

**Why it earns its place.** It replaces a rubber-stamp human checkoff and a
fail-open label with a machine-readable hold list and a real post-merge review
path. It removes a gate (the pre-merge read) rather than adding one.

**Buys:** speed (fewer human blocks) + reliability (holds actually hold).

**Cost / risk.** Under green⇒merge an incomplete hold list silently auto-merges
the wrong thing — the hold list's completeness is load-bearing. And review-owed
must be visible on the host doing the merging.

### F. Doctor + mandatory verify-host

**What.** A read-only `doctor`: is this run worth trusting — right base ref, full
history present, hooks or CI installed, range non-PARTIAL? And make `verify-host`
mandatory per adopted skill ("a skill that was never executed is a draft").

**Why it earns its place.** Auto-merge and proof both trust that the gate ran
against the right base; a stale-bundle proof is not evidence. pstack's principle
applied to us: a run on a stale/PARTIAL range is not proof.

**Buys:** accuracy + reliability. **Cost:** small; fold into the suite if it can
be a check.

### G. Sequencing and reversibility

1. Vet this plan (fresh Claude session), revise.
2. File the issue (issue-first intake), with this doc as the basis for the intent.
3. Land the cheap/reversible items on a branch off `golden-v1-harness-main`:
   D (if verified) → B → C → A → E → F.
4. Per-item retirement of checks (C) is reversible independently.

**Anchor / reversion.** `main` is already tagged `golden-v1-harness-main`
(`ac08350`); work rides a branch/PR, so "don't like it" = don't merge. Nothing
force-tags an existing tag. `golden-v1-harness-main` and the claude-harness
`engineering-workflow--v1.4.x` tags are never moved or deleted.

---

## 3. Explicit non-goals

- No UI/desktop driver (this repo has no app surface).
- No eval **runner** — #1 owns automation; the map is a document until then.
- No blanket gating; exactly **one** required server gate.
- No path filters on the per-PR job.
- Do not move *textual* checks off the suite — keep greps for textual footprints.
- Do not touch or retag `claude-harness` or its `engineering-workflow--v1.4.x` tags.
- Do not disturb the in-flight `cozyharness_full_workflow` work in `~/dev/cozyharness`.

---

## 4. Open questions for the vetting session

1. Does reshaping #8 in place conflict with the repo's issue-first / intent
   rules, or is a new transformation issue cleaner?
2. Can the behavior map's maintenance loop be honest without a runner (pre-#1),
   or does a document-only map inevitably rot? Is the trigger enforceable?
3. Is the one-in-one-out rule better as prose or as a check — and if a check,
   does it earn its place?
4. Is the symlink lever real (does Claude Code resolve `.claude/skills` symlinks)?
5. Does the #33 required check interact badly with the existing rulesets
   (`require_extra_approval_for_unattributed_changes`, 0 approvals)?
6. Does retiring the three behavior-proxy greps actually leave the system *more*
   reliable, or does it trade always-on enforcement for a periodic pass? Where is
   the line?
7. Does the plan keep `main` host-neutral (per #35), or does any item leak a
   host-specific rule into canonical docs?
8. Is `doctor` a real need or scope creep? Is `verify-host`-mandatory enforceable?
9. What is the smallest first step that proves the whole direction (a wedge)?
10. What in this plan does **not** earn its place, and should be cut?

---

## 5. Vetting brief (what the fresh session must do)

Read, in order: `AGENTS.md`, `CONTEXT.md`, `SYSTEM-INTENT.md`, `STATUS.md`,
`docs/engineering-workflow.md`, `REVIEW.md`, `tests/validate.sh`,
`docs/adr/*`, this document, and the issues `#1 #8 #33 #34 #35 #39 #42 #45`
(via `gh issue view`). Verify claims against the repo rather than trusting this
summary.

Then assess, in writing: (1) is each item sound and does it earn its place;
(2) does it increase speed/accuracy/reliability and by what mechanism;
(3) conflicts with existing contracts or invariants; (4) hidden costs, failure
modes, and long-term risks (especially map rot and hold-list completeness);
(5) a prioritized set of corrections; (6) a verdict — adopt / adopt-with-changes /
reject — and the smallest first wedge. End with a `HANDOFF:` line.
