# Fresh-session vetting — Verification & Gate Leanness plan

**Vetter:** fresh Claude Code session (Opus 5.5), herdr pane `w1:p44`, 2026-10-05.
**Mode:** read-only; no repo edits. Ran `tests/validate.sh origin/main..HEAD`
(14 ok, 0.55 s), `gh` reads, and a scratchpad symlink probe (deleted after).
**Plan vetted:** `handoffs/2026-10-05-verification-and-gate-leanness-plan.md`.

## Verdict

**Adopt with changes.** Item B (#33) is the core. E (#39) is already approved.
D (symlink) is verified. **C and F are cut**, and **A is reduced** to authored-run
files.

**Wedge:** #33 in *advisory* mode — add `gate.yml` with **no ruleset change**;
open one PR with a deliberately red commit and one green PR carrying a commit
pushed by the agent identity; then flip the check to required. Proves the floor,
the ruleset interaction, and the time cost; reversible by deleting one file.

**Top finding:** the plan's E diverges from operator-approved #39's hold list and
inverts tracker order (#42 is *blocked by* #39; ADR 0005 fails `adr-numbering` on
main without 0003/0004).

## Plan claims that are wrong or unverified

| Plan claim | Repo reality |
|---|---|
| `skill-copies` covers 2 of 5 skills | False on main — main has 2 plugin skills and the check covers all 3 pairs (`validate.sh:102-109`). The "5" is claude-harness (#34). |
| E: "narrow" hold = `tests/`, `.github/**`, `.githooks/**`, trio, AGENTS.md | Not the approved list. #39 (approved 2026-10-02) holds only `tests/validate.sh`, `.github/workflows/**`, `.githooks/**`; AGENTS.md/trio/ADRs auto-merge on green. |
| E: "#42 first" | Backwards: #42 is Blocked by #39; #39 is Blocked by #33/#34. #42 also edits claude-harness, which the plan's non-goal forbids. |
| E: "ADR 0005" on main | `adr-numbering` is contiguous and main has only 0001/0002 — ADR 0005 fails until #40/#41 land 0003/0004. |
| C: proxies "fail on rewording" / "train people to ignore red" | No evidence; `git log -S` shows the pinned strings unchanged since `9249328`. |
| C vs §3 non-goal | Contradiction — all three C candidates grep repo text (Test §5). |
| sync-rule "vacuous" is a gap | It is the intended trigger (`validate.sh:28`). |
| F: "range non-PARTIAL" | "PARTIAL" is not in repo vocabulary (breaks Design §3). |

**Verified correct:** golden anchor, 35 witnesses, sub-second gate,
`allow_auto_merge:false`, ruleset fields.

**Missed fact:** on this machine a Claude session loads **both** the
engineering-workflow plugin (1.4.2, from claude-harness) **and** the project
`.claude/skills` copies (from main) under the same names; content differs (66
lines in engineering-workflow, 9 in factory-orchestrator). A live accuracy
failure — belongs to **#43**.

## Per-item dispositions

- **A — Behavior map: unsound as written.** The recipe format already exists
  (`.claude/verify-host.md`). The map adds a README sweep order + a maintenance
  cadence, and **nothing triggers the cadence** — proven by STATUS.md (stale
  since 2026-09-13, silent on #33–#52 despite "maintain with each milestone")
  and #8 (`needs-triage` since Build). "Total at the feature level" is
  unmeasurable. **Reduce** to one authored-run file per behavior, written only
  when proof is needed, run at an event that already happens (an adoption PR or
  an incident-fix close).
- **B — CI gate (#33): sound, highest value.** Named failures it prevents: fresh
  clones/CI workers have no gate; pre-push checks the wrong ref (#23); pre-push
  fails in every linked worktree (#45), so `dispatch` workers push `--no-verify`
  and run with no gate today. Buys reliability: one unbypassable gate with an
  explicit base. **Cost understated:** it is a merge-path, heavy-lane change and
  must rewrite in one commit Test §5 ("CI wiring waits on #1"), Deploy §3 ("403
  on this private free-plan repo" — now false), and CONTEXT.md ("CI gate (none
  exists until #1)").
- **C — Retire the 3 proxy greps: cut.** No named failure; each check is ~1 line
  / ~0 ms; retiring removes the always-on guard on AGENTS.md:26 (the text agents
  read) and costs Test §4 ceremony. The one-in-one-out rule only repeats Test §2
  and §5.
- **D — Symlink: real; choose D or #34, not both.** Verified on Claude Code
  2.1.292 macOS (probe → YES; control → NO). Removes 2 of 3 copy pairs (the
  tracked `.agents/skills/factory-orchestrator` pi copy remains), shrinking
  `skill-copies` to one `cmp` line — smaller than #34's 12-line loop. Unverified:
  Windows (`core.symlinks=false`) and pi. Witness row at `validate.sh:216`
  changes meaning and must be retired against an issue.
- **E — Merge policy (#39): sound and already approved.** The plan's version adds
  an unapproved hold widening, wrong order, and the ADR-numbering blocker. Also
  incomplete: green⇒merge contradicts STATUS.md:43-45 ("never let a hook replace
  that with an auto-yes"), the light-lane "no auto-approval" text
  (`docs/engineering-workflow.md:171-176`), and the CONTEXT.md `gate` / `light
  lane` / `merge gate` entries — all must change in the #39 commit.
- **F — Doctor: cut.** Every sub-check is already covered: shallow clone/bad range
  fails `sync-rule` (`:27`) and `--witness` (`:192`); after B the CI checkout pins
  base + full history; once CI is required, local hooks don't matter. The one real
  gap: the default run **silently falls back to `HEAD~1..HEAD`** (`:157-160`), so a
  pasted "green" can be over the wrong range. **Fix with one line:** print the
  range in the summary line. `verify-host`-mandatory belongs in #35's
  "Rules for every adoption PR" as pasted evidence.
- **G — Sequencing: wrong.** Use tracker order: **#33 → (#34 or D) → #40/#41 →
  #39 → #42**.

## Conflicts with existing contracts

- **Sync rule vs CI:** the PR range is a union of commits; "three files, one
  commit" can't be seen per-commit. Option: `allowed_merge_methods: ["squash"]`
  on main so the checked range equals the landed commit.
- **Test §4:** C and D retire witness rows → each must cite a retiring issue.
- **Host neutrality (#35):** E/F leak if canonical text names `cmu`, `dispatch`,
  or `.claude/verify-host.md`. State the contract instead — e.g. *"review owed =
  commits on main since the last board-only STATUS.md commit."* Minor existing
  leak: the `t1` checks pin Claude CLI facts inside `validate.sh`.
- **Pre-push envelope:** once B is required, close **#23 as superseded**; still fix
  **#45** with one line (unset `GIT_DIR GIT_WORK_TREE` before `validate.sh:14`).

## Hidden costs and risks

- **Map rot** is certain without an event trigger (see A).
- **Hold-list completeness:** define it mechanically as the files the required
  check executes (`gate.yml`, `tests/validate.sh`, `.githooks/**`). That set is
  complete against "a PR weakens its own gate" — AGENTS.md and the trio cannot
  weaken it (`agents-commands`, `stage-parity`, `t3-*` fail on removal). #39's
  list is correct; the plan's additions protect process prose, a different risk.
- **The hold is prose only:** one identity merges, so CODEOWNERS/required review
  can't enforce it; it can fail open like `flagged-risk` did.
- **"Fails closed if CI is removed" has no detector** — rulesets aren't in git.
  The board refresh could `gh api .../rulesets` to detect removal.
- **#39's `ADR:` PR-body check is presence-only** — `ADR: none` satisfies it.
- **No `bypass_actors`** on the ruleset → once the check is required, an Actions
  outage blocks all merges, including the operator's.

## Answers to the 10 open questions

1. Reshape #8 in place? **No** — one request, one issue. File a small issue for
   the authored-run format; leave #8 as the ledger.
2. Map honest without a runner? **No** — cadence-triggered docs rot here; a run is
   honest only when an existing event forces it.
3. One-in-one-out as prose or check? **Neither** — Test §2/§5 already cap growth.
4. Symlink? **Yes** (Claude Code 2.1.292 macOS); Windows/pi unverified.
5. Required-check conflict with rulesets? **Not structurally**; the PUT replaces
   the whole array (resend it). Test `require_extra_approval_for_unattributed_changes`
   with an agent-identity PR; decide an admin bypass.
6. Retiring the 3 greps more reliable? **No** — text gets a check, behavior gets an
   authored run; these three are text.
7. Host neutrality? **B/C/D yes; E/F leak** unless they name contracts.
8. Doctor / verify-host mandatory? **Doctor = scope creep** (range echo instead);
   verify-host enforceable only as pasted evidence in #35 PRs.
9. Smallest wedge? **#33 advisory.**
10. What does not earn its place? **C's retirements, doctor, the map's sweep order
    and cadence, a one-in-one-out check, and E's added hold paths.**

## Corrections, in priority order

1. Align E with approved #39 (or bring the widening to the operator explicitly);
   fix order to **#33 → #34/D → #40/#41 → #39 → #42**.
2. Note ADR 0005 needs 0003/0004 first, or `adr-numbering` fails.
3. Non-goal wording → "never retag existing tags; change claude-harness only
   through approved issues (#42)."
4. Give B full scope: trio + CONTEXT.md rewrites, heavy lane, #23 superseded,
   #45 one-line fix.
5. Cut C and the one-in-one-out rule.
6. Replace F with a range echo in `default_run`'s summary line.
7. Replace A with authored-run files in the `verify-host.md` shape, run at
   adoption/incident close — no cadence, no README.
8. Choose D **or** #34. D is leaner if no checkout is on Windows.
9. `REVIEW.md:20`: skip only "the exact assertion each check makes", **not** "the
   synced trio" as a surface — closes the partial-check license with one sentence.
10. List the human-gate statements E must rewrite.
11. Route the plugin-vs-project skill dual-load to #43.
12. Optional: squash-only merges on main; a ruleset-presence read at board refresh.
