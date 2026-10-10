---
name: factory-orchestrator
description: Orchestrate a multi-agent build via herdr worker sessions. Use when continuing a tracked build, dispatching tickets to worker sessions, supervising parallel agents, or when asked "where are we" on the build.
---

# Factory Orchestrator

You orchestrate the factory build: you manage worker sessions, you do not write
factory code yourself. Read `.factory/design.md` for the system being built. This
skill is the full instruction set; `.factory/supervision.md` is only a pointer back
here. The live frontier is GitHub — nothing in a file outranks it.

## The build

GitHub issues on the repo under orchestration, label `ready-for-agent`, blocking
edges in each issue body. Done when every ticket is closed with verification
evidence. A design doc (`.factory/design.md` in this repo's layout) states the
system being built, ticket breakdown, and definition of done — the live
frontier is GitHub, nothing in a file outranks it.

## The per-ticket loop (the contract)

1. **Orient:** `gh issue list --label ready-for-agent`. The frontier is any ticket
   whose blockers are all closed.
2. **Dispatch:** fresh herdr pane per ticket (`herdr tab create` → note pane_id →
   `herdr agent start <name> --kind pi --pane <id>` → `herdr agent prompt <pane>
   "$(cat promptfile)"` with the Worker Prompt Template below). One ticket per
   session, never reused. Parallel-safe tickets may run in parallel panes; blocker
   edges decide order. Pre-answer the 2–3 ambiguities you'd have about the ticket
   IN the worker prompt, and always include your own pane id so the worker can
   execute its final direct ping (set `ORCH_PANE_ID=<your pane id>`; `herdr agent list`
   shows you focused).
3. **Watch:** `herdr agent list` to poll (JSON; pane_id + agent_status). Read a
   screen with `herdr agent read <pane>` only on idle or long stall. If a worker
   goes idle without closing the issue, it stalled or truncated: read its screen,
   send a resume directive with tighter scope (numbered slices, commit after each).
4. **QC — run the gates yourself.** GitHub is the claim; your terminal is the proof.
   Per ticket: run the acceptance criteria with your own commands, run the full
   suite (`cd factory && python3.11 -m unittest discover -s tests -t .`), review the
   diff against the design doc (lean? stdlib? no logic in cli.py? no speculative
   abstraction?), and a **test-justification pass**: every test must guard a behavior
   no other test guards. Findings go on the reopened issue with the failing command —
   never a vague "please fix." Also: did this diff smuggle in a decision that needed
   an ADR?

   **Adversarial pass (mandatory):** the orchestrator's own QC is a single point of
   bias — it inherits the orchestrator's assumptions (a brittle gate spec, a wrong
   guess at what a worker will write). Run the **`adversary` subagent** on the diff
   (agentScope `project`; hostile review that assumes the change is wrong: edge cases,
   injection, race/ordering, silent failure, spec violations, scope creep) and fold its
   findings into the QC verdict. The adversary costs little and breaks the author-boss
   bias loop. For the fastest loop, invoke it per-diff before blessing; at minimum run
   it on the aggregate diff each batch. NOTE: adversary review catches *code* bugs;
   brittle gate specs (a gate that greps the wrong pattern) are caught by
   `factory gatecheck` (issue #17) and by idiomatic worker output diverging from an
   over-specific gate — run both.
5. **Handoff before spin-down.** Workers end by pinging the orchestrator session
   directly (`herdr agent prompt <orcha_pane> "HANDOFF: …"` — lands in this session)
   and leave the same line as an in-buffer fallback; any ADRs are pushed to the remote.
   Verify on QC: watch for the direct ping or read the screen for the line; ping the
   worker with the handoff addendum if absent. Then close the pane (`herdr tab close`).
6. **Checkpoint.** Report to the operator between tickets: what landed, diff stats,
   QC result, what's next. Operator releases the next ticket. Trivial tickets may be
   batch-approved; big ones get a real look.

**Merge hold (ADR 0005):** never merge a PR whose `tests/validate.sh --lane`
prints `flagged: yes` — it touches `tests/validate.sh`, `.github/workflows/**` or
`.githooks/**` — without a named human checkoff recorded in the thread, or a
recorded operator delegation. Label it `flagged-risk` and report it as merge
held. One GitHub identity merges, so GitHub cannot enforce this; you do.
Everything else may land on a green gate and is reviewed after merge.

**ADRs during the build:** a decision that is hard to reverse, surprising without
context, and a real trade-off gets a one-paragraph record as the next numbered file
in `docs/adr/` (format examples: `docs/adr/0001-*.md`). Commit and PUSH it — an
unpushed ADR is a decision the orchestrator can't see. If it's visible in code, skip.

**Halt rule:** two consecutive QC failures — on any tickets, any workers — means
stop the chain. Do not dispatch the next ticket. Revisit the worker prompt or the
design doc with the operator first; a chain that keeps failing is producing debt,
not work.

## Worker prompt template

> You are a worker in the pi harness factory build. Work GitHub issue #N ONLY
> (`gh issue view N`).
>
> Process contract (non-negotiable):
> 1. Read `.factory/design.md` first (cite the section relevant to your ticket).
> 2. Test-first: one red-green slice at a time. **Every test must justify itself —
>    if you can't say what behavior it guards that no other test covers, don't write it.**
> 3. Lean: stdlib first, shortest working diff, no speculative abstractions, no config
>    for values that never change. Core must run and pass with optional deps absent.
> 4. Before closing: run the full suite from `factory/` (`python3.11 -m unittest
>    discover -s tests -t .`), review your own diff against every acceptance criterion,
>    push, close #N with a comment showing the verification commands and output.
> 5. Go idle. Do NOT start any other ticket.
> 6. Handoff before idling (the orchestrator spins the session down after this):
>    a. **ADRs**: if the diff landed a decision that is hard to reverse, surprising
>       without context, or a real trade-off, write a one-paragraph record in
>       `docs/adr/NNNN-slug.md` and PUSH it — an unpushed ADR is a decision the
>       orchestrator can't see.
>    b. **Report back — always.** A worker that finishes (or stops early) MUST
>       leave a `HANDOFF:` line in its final in-buffer message, AND send the
>       direct ping (step c). An idle pane with no `HANDOFF:` line is a dead
>       spot: the orchestrator must treat it as stalled, read its screen, and
>       reconcile it — never assume work landed. Sending only the underlying
>       closure (issue, PR) does NOT satisfy the report-back contract; the
>       orchestrator uses the `HANDOFF:` line to know you're truly done.
>    c. **Final ping**: ping the orchestrator session directly — run
>       `herdr agent prompt <ORCH_PANE_ID> "HANDOFF: ticket #N | closed=<yes/no> | pushed=<sha range> | ADRs=<ids or none> | followups=<one line or none>"`
>       so the message lands inside the orchestrator's session. Also end your last
>       in-buffer message with the same line as a greppable fallback. Then idle — do
>       not start anything else.
>
>    > `ORCH_PANE_ID` is passed in the worker prompt below; if absent, read it from
>    > `herdr agent list` (the focused pi-orch pane). If herdr isn't on PATH or the
>    > prompt fails, the in-buffer line alone satisfies the contract.
>
> Note: `pip install -e factory/` has been run on this machine. If another worker is
> running in parallel, pull --rebase on push conflicts.

## Failure modes seen (and the counters)

| Failure | Signal | Counter |
|---|---|---|
| Worker batches multiple tickets without pushing/closing | git log ahead of origin, issues open, worker deep into next ticket | Interrupt via `herdr agent prompt`: stop, push, close each with evidence, idle. Protocol restated in template step 5. |
| Response truncated during long planning | idle, nothing committed, screen ends "Response was truncated" | Resume directive with numbered slices + commit-after-each + a line cap on new modules. |
| Silent skip in gate logic (missing tier field) | stage records `unknown` with zero verdict events | Caught by orchestrator QC reproducing acceptance criteria by hand. The lesson: QC runs the gates, always. |
| Design ambiguity stall (e.g. `scope` param) | long "working" with no commits | Pre-answer the 2-3 ambiguities you'd have about the ticket IN the worker prompt. |
| Session wraps silently — no ADRs pushed, no handoff, orchestrator learns nothing | idle pane, no `HANDOFF:` line, `git log` shows local ADR commits never pushed | Handoff protocol in template step 6; orchestrator reads the screen for the `HANDOFF:` line on QC and pings the worker if absent. |

## Mechanics cheatsheet

- New worker pane: `herdr tab create` → note pane_id → `herdr agent start <name> --kind pi --pane <id>` → `herdr agent prompt <pane> "$(cat promptfile)"`
- Poll: `herdr agent list` (JSON; pane_id + agent_status per agent)
- Read a screen: `herdr agent read <pane>`
- Send input: `herdr agent prompt <pane> "…"`
- Close a retired pane: `herdr tab close <tab_id>`
- Worker sessions default to `openrouter/auto` (set in `~/.pi/agent/settings.json`).
  Cost display for auto is broken-by-registry (-1e6 sentinel); the footer extension
  filters negative costs. Track spend qualitatively, or pin a priced model if precise
  per-ticket cost matters.
- Context meters: the context-footer extension shows live fill per pane
  (green <50%, yellow <75%, red ≥75%). A worker approaching yellow mid-ticket should
  finish its current slice, commit, and be replaced.

## Mechanics by host

Appendix — the host-neutrality seam: the per-ticket loop above is the contract and does not change per host — only the
spawn/poll/ping/close mechanics do. Three hosts covered. Whatever the host, GitHub
stays the frontier and the HANDOFF line in the worker's final output is the
greppable fallback every host must satisfy.

### herdr + pi (reference host)

Use the Mechanics cheatsheet above as-is: `herdr tab create` / `herdr agent start
--kind pi` to spawn, `herdr agent list` to poll, `herdr agent read` to inspect,
`herdr agent prompt` to ping (including the worker's HANDOFF ping back into the
orchestrator pane), `herdr tab close` to retire.

### Claude Code headless

Spawn one non-interactive `claude -p` session per ticket inside a tmux window or
as a background session; verified against `claude --help`:

- Spawn: `claude -p --output-format stream-json "$(cat promptfile)" >log-<ticket>.log 2>&1`
  in a fresh `tmux new-window` (redirect, or output is lost when the process
  exits); streaming JSON prints `session_id` as it goes, so Poll/Read work
  mid-run and Ping's resume-id is recoverable (or pin `--session-id <uuid>` at
  spawn). `claude --bg` (prints a session id) works too. One session per ticket,
  never reused.
- Poll: `claude agents --json` lists background sessions (add `--all` for
  completed ones); for tmux panes, process liveness plus the captured output.
- Read: tail the redirected log file (or `tmux capture-pane -p -t <pane>` for a
  pane you didn't redirect); for a `--bg` session, `claude logs <id>` prints its
  recent terminal output.
- Ping: `-p` with default text input is one-shot, and `--input-format stream-json`
  holds stdin open for follow-up turns — otherwise steer a finished or stalled
  worker with `claude -p --resume <session-id> "<tighter-scope directive>"`. Stop
  a runaway background session with `claude stop <id>`.
- Close: a `-p` session exits at completion; `claude rm <id>` retires a
  background session, `tmux kill-window` retires a pane.
- HANDOFF: no cross-session ping channel; the worker's final output line carries
  `HANDOFF: …` and the orchestrator greps the log/captured pane for it.

Headless trust: `claude --help` says the workspace trust dialog is SKIPPED in
non-interactive mode; "Only use this in directories you trust." Silent: settings
files that fail validation are ignored with no error. Only dispatch headless
workers in trusted checkouts.

### Codex sessions

`codex` is not installed on the reference machine; the following names the
known `codex exec` entry point but every flag must be verified against
`codex --help` on the host before dispatch. The mechanism is the generic one:

- Spawn: one non-interactive exec session per ticket (`codex exec` with the
  worker prompt as its input), in its own terminal/pane or with output
  redirected to a per-ticket log. One session per ticket, never reused.
- Poll: session/process liveness plus the tail of its captured output.
- Ping: assume no mid-run steering channel. Steer by starting a follow-up exec
  session against the same working tree carrying a tighter-scope directive
  (numbered slices, commit after each).
- Close: the session exits at completion; kill the process to abandon.
- HANDOFF: the worker's final output line carries `HANDOFF: …`; the
  orchestrator greps the captured output for it.
