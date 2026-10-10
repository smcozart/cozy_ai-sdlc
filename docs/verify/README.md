# Behavior files — authored runs (#62)

A behavior file verifies one agent behavior that has no textual footprint
for `tests/validate.sh` to grep (Test §5). The file IS the run: a fresh
session gets the prompt, and the runner compares the transcript to the pass
bar. Same shape as `.claude/verify-host.md`. These files live in `docs/verify/`
because the behaviors are host-neutral contracts; `.claude/` holds Claude-host
config.

## Format

One file per behavior, `docs/verify/<behavior>.md`, four sections:

1. **Prompt** — given verbatim to a fresh session. It names the task, not the
   behavior under test.
2. **Expected observations** — what a correct session does, in order.
3. **Pass bar (pinned)** — PASS/FAIL stated against the transcript and the
   artifacts, not against plausible prose. Read evidence or it is FAIL.
4. **Run mechanics (pinned)** — the setup (a clean clone at a pinned sha, the
   planted state), the spawn command, the sandbox (no tracker writes, no
   push), who runs it, and where the run is pasted.

The subject's clone must not contain the behavior file, or the session can read
its own pass bar. Worked example: [`close-without-proof.md`](close-without-proof.md).

## When a run happens

Only at events that already happen. There is no cadence.

- **Adoption PR** — the PR that lands or changes the contract a behavior file
  tests writes the file if it is missing, runs it, and pastes the run in the PR.
- **Incident-fix close** — the close of a fix for an incident class that a
  behavior file covers pastes a fresh run. A new incident class with no
  textual footprint gets its file in the same close (eval-on-incident).

A file is written only when one of these events needs the proof. When a
change alters the contract a behavior file tests, the same PR updates or
re-pins that file; the pinned sha is the golden tag, re-pinned only at these
events.

## #8 corpus map

| #8 item | Home | Reason |
|---|---|---|
| T1 HIGH: HANDOFF grep fallback on every spawn path | left on #8 | Text in the FO skill, already fixed. A check is admitted on recurrence (Test §2). |
| T1 MED: `-p` "no mid-run stdin" false | left on #8 | Text fact about the CLI, fixed. Check on recurrence. |
| T1 MED: trust dialog misstated | `t1-trust-wording` check | Text; the check stays. |
| T1 MED: Spawn without session id | `t1-spawn-session` check | Text; the check stays. |
| T1 LOW: `>log` clobber | `t1-log-clobber` check | Text; the check stays. |
| T1 LOW: Codex hedge; "Poll reads the log" | left on #8 | Text, LOW, fixed. Check on recurrence. |
| T3 MED: label wording drift | `t3-label-drift` check | Text; the check stays. |
| T3 MED: no precedence framing | `t3-precedence` check | Text; the check stays. |
| T3 MED/LOW: no canonical pointer; vague vocabulary; ADR 0001 dropped | left on #8 | Text, fixed in AGENTS.md. Check on recurrence. |
| Meta-lesson: pin exact wording in acceptance criteria | `intent-conversation.md` (not yet written) | Ticket-authoring behavior. Write at the intent-conversation adoption PR (#35). |
| Sync-content drift (prose parity of the trio) | left on #8 | Text; it needs a check, not a behavior file. |
| Protection-scope hole | Test §4 | Folded into contract text (4ea8957). Reviewer behavior; write a file if it recurs. |
| Holistic workflow review (five priorities) | #1, #33 | Planning input, not corpus items. |
| Deploy: carried notes owned by a non-author, never resolved by silence | left on #8 | Behavior. Write `review-loop.md` at the next carried-finding incident (#18 is the live case). |
| Deploy: merge-gate honesty (401 vs absence); merge hold (ADR 0005) | [`merge-policy.md`](merge-policy.md) | Behavior. Written at the ADR 0005 adoption PR (#39). |
| Maintain: eval-on-incident; prose parity | this file; sync-content row | The trigger above is the eval-on-incident rule. |
| Close without proof (Test §1) | [`close-without-proof.md`](close-without-proof.md) | Contract on main today. This is the proof-of-concept file. |
| Dispatch hold (never merge a held PR) | `dispatch-hold.md` (not yet written) | The `dispatch` skill is not on main. Write at the #42 adoption PR. |
| cmu pickup (read-only catch-up) | `cmu-pickup.md` (not yet written) | `cmu` is not on main. Write at the #31 adoption PR. |
