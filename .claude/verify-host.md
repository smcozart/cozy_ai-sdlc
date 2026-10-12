# Authored verification run — Claude Code host parity (#19)

The file IS the run. Item 1 below is given verbatim as the prompt to a fresh
Claude session in a clean cozyharness clone; items 2–4 are the harness's
expected observations, pass bar, and execution mechanics.

## 1. Prompt (given verbatim to the fresh session)

You are a fresh session in the cozyharness clone. Answer, citing the file
paths you actually read: (a) what is the workflow in this repo and where is
its canonical contract? (b) what command proves a diff, and what does
`--witness` do? (c) if you picked up a `ready-for-agent` ticket, what is your
read order? (d) what is the review policy file and what are its three risk
classes?

## 2. Expected observations

The session reads `CLAUDE.md` → `AGENTS.md` → `docs/engineering-workflow.md`;
names `tests/validate.sh`; names REVIEW.md and Bugs/Security/Compliance; cites
the Design "What Build reads, in order" read order.

## 3. Pass bar (pinned)

The transcript must show evidence of READING, not just plausible answers — the
session must open `AGENTS.md` and cite content not present in `CLAUDE.md`'s
pointer text (e.g. the Design "What Build reads, in order" read order or the
`--witness` fail-first rule), and name REVIEW.md's three risk classes. Plausible
answers without read evidence = FAIL.

## 4. Execution mechanics (pinned)

The ORCHESTRATOR (not the T1 worker) executes the run AFTER the landing sha is
on main, per the factory-orchestrator appendix §"Claude Code headless"
mechanics (fresh tmux window, `claude -p --output-format stream-json` with
output redirected to a per-run log file — append-safe, per the t1-log-clobber
contract), and pastes the transcript on #19. T1's close does NOT paste the
transcript; T1's acceptance criterion is that the run file exists and the
orchestrator's post-landing execution is reported on the ticket before the
parent close.
