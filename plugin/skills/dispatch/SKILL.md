---
name: dispatch
description: >
  Dispatch approved work from this conversation: start one fresh, isolated
  worker per ready-for-agent issue (a herdr pane over its own clone when
  herdr runs, else a worktree), respect blockers and
  overlapping files, and own progress, QC, one adversary pass, merge gates,
  and retirement. Dispatch is automatic — it fires whenever
  the live frontier is non-empty, immediately after any approval that leaves
  ready-for-agent work, and on every worker idle notification or QC
  completion, never by background polling (on herdr, `herdr agent wait` and
  `herdr agent list` are the idle notification). Also use when the developer says
  "go", "dispatch", "work the issues", "start the swarm", or "knock out the
  backlog". Record any missing approval through intent-conversation first.
  The orchestrator coordinates; it does not implement tickets.
---

# Dispatch

Turn "approved" into "built, proven, merged" without being asked twice. The
orchestrating session runs this skill; it never implements a ticket in its own
checkout. A request or a plain "go" approves only the issue it is about, never
the whole unapproved backlog — that gate is `intent-conversation` Move 3.

**Companion skill:** `cmu` reports what landed, what is in flight, and what
needs the developer since they last looked; `cmu` never triggers this skill —
dispatch's own triggers (above) are unchanged.

Planning, read-only or explicit-pause requests override dispatch. Workers never
recursively dispatch — the worker brief below forbids it.

## Move 1 — Orient

Count open PRs labelled `flagged-risk` or otherwise awaiting a named human
checkoff first — not PRs awaiting your own QC. Nonzero: launch nothing new;
existing workers and the conversation continue.

Frontier = open, labelled `ready-for-agent`, zero open `blocked_by`, not
labelled `ready-for-human`, not `wontfix`. Fetch every page. Read each
candidate's blocker summary (`gh api repos/{owner}/{repo}/issues/<n>`); missing
or errored data means unknown, not zero — skip it this pass. Require the
issue's intent file to exist and cite the issue, committed on `<base>` or on
`origin/t<n>-<slug>` (`intent-conversation` Move 2); an uncommitted or missing
intent is not a worker brief. Re-check the frontier immediately before each
launch, not just at the top of the move.

An operation that provisions, first-deploys, migrates or changes identities
stays human-run even if labelled — never dispatched.

## Move 2 — Batch

Read `**Touches:**` from each candidate's `intent.md` — a JSON array of
repo-relative paths/globs. Missing, malformed, empty or unbounded means
unknown. Prove pairwise disjointness against other candidates **and** active
workers; prefix/glob ambiguity means overlap. Contract producer/consumer pairs
run in sequence even when disjoint.

Concurrency: 2 workers by default, 1 when any candidate's Touches are unknown
or overlapping, 0 new launches while any PR waits on a human gate. The
developer can change this in plain language for the rest of the conversation.

Reserve issue, branch, worktree or clone path, Touches, base SHA (`git rev-parse
origin/<base>` at reservation, `<base>` as in Move 5; when
`origin/t<n>-<slug>` exists, `git merge-base origin/t<n>-<slug>
origin/<base>`), worker/session id, PR
and state under the repo's own ignored `.factory/` directory before launching.
Reconcile against Git/worktrees/PRs before retrying or re-entering after a
restart; never double-launch. This is local recovery state, not a second
tracker.

## Move 3 — Dispatch

Branch name is always `t<n>-<slug>`. When `origin/t<n>-<slug>` exists (it
carries the intent), the worktree checks it out (`git worktree add <path>
t<n>-<slug>`), never creates it with `-b`; that one worktree is the worker's,
and a harness worktree is never made beside it. On herdr there is no
worktree: the worker's own clone checks the branch out instead. Detect and
use, in this order:

1. **herdr**, when `HERDR_PANE_ID` is set and `herdr` is on `PATH`;
2. your harness's own session-creation tool;
3. a sub-agent with worktree isolation;
4. a child headless session in a worktree.

A sub-agent over a shared checkout is never a worker, whatever the host.

### Mechanics by capability

| Capability | Launch | Watch / steer |
|---|---|---|
| herdr (`HERDR_PANE_ID` set, `herdr` on `PATH`) | One full clone per ticket, never a worktree: `git clone <url> ~/.factory/<repo>/workers/w<n>` (never inside the repo or beside it), then `git checkout t<n>-<slug>` when `origin/t<n>-<slug>` exists. Then, inside the clone, install the tools its committed `.claude/settings.json` names, at project scope: for each `extraKnownMarketplaces` entry, `claude plugin marketplace add` its `source` `--scope project` when this machine does not know it yet, then `claude plugin marketplace update <name>`; then `claude plugin install <id> --scope project` for each `enabledPlugins` entry set to `true`. An install that fails is a launch failure: do not start the worker; report the failure. `herdr tab create --cwd ~/.factory/<repo>/workers/w<n>` → note the pane id → `herdr agent start <name> --kind <worker kind from AGENTS.md (default claude)> --pane <id>` → `herdr agent prompt <id> "$(cat ~/.factory/<repo>/logs/w<n>-prompt.md)"` carrying the herdr brief below. Accept the folder-trust prompt in the new pane only for a fresh clone of this repo itself (#106). | `herdr agent list` (pane id and status) and `herdr agent wait <id>`; `herdr agent read <id>` on idle or a long stall; steer with `herdr agent prompt <id> "…"`. The worker pings back with `herdr agent prompt <ORCH_PANE_ID> "HANDOFF: …"`; `ORCH_PANE_ID` is your own `HERDR_PANE_ID`. |
| Desktop app with a session-creation tool (`create_session`) | Worktree workspace, autopilot kickoff carrying the worker brief below, coordinated with the creator, notified on idle; title it `#<n> <slug> worker` when the tool takes one, so the sidebar reads as a board. The worker renames its own branch to `t<n>-<slug>`, unless `origin/t<n>-<slug>` exists; then it checks it out. | Idle notification; its own session-inspect/session-message tools; keep the returned session id. |
| Harness with a worktree-isolating sub-agent tool (its own worktree option) | Its documented worktree-isolation and background-completion mode; the worker checks out or creates `t<n>-<slug>`. | Its native completion/message/resume tools; keep the returned identifier. |
| CLI with headless child sessions (`--worktree`) | A child headless session in its own worktree on branch `t<n>-<slug>` (verify: sibling worktree, exact branch). A shared-checkout sub-agent is not a worktree and may be used only after you have created the worktree yourself, or not at all. | Process completion and structured output; resume the exact session id, not an ambiguous "continue latest". |

A worktree shares its main checkout's tool installs: nothing to install there.

Before real unattended work, confirm in that exact worktree — never infer from
the parent — that a guardrail source is verifiably loaded: the repo's committed
hooks. Prove it with a harmless
denial: the worker's first turn runs one infra-flavoured command (for example,
a cloud CLI read like `az account show` or a destructive-looking dry run) that
a loaded guardrail must deny. If nothing denies it, that issue runs serially in
the supervised parent instead of unattended — do not relax this to get a
worker running. **herdr row only:** a worker in a herdr pane counts as
supervised, because the developer can see the pane, read it and step into it.
It runs in its normal permission mode, never a bypass mode, and skips this
first-turn denial check: its first message line is `herdr pane: supervised`.
No other host is supervised this way: every other host keeps the check above
and its serial fallback.

## Move 4 — Watch

Report launches, blocked/stalled workers, PR handoffs, gate results and
retirements in this conversation as they happen. On herdr, watch with
`herdr agent list` and `herdr agent wait <id>`, never a sleep loop. An idle worker with no
`HANDOFF:` line is not success — send it a concrete same-ticket correction,
never a new issue for the same scope.

**Keep a one-line worker roster.** Every Watch report and every turn that
stops carries it, directly above the `Needs you:` line, one entry per worker
session **this conversation launched**, in this shape:
`Workers: #12 handed off (PR 12, awaiting QC) · #14 running · #9 retired — dismiss it`.
The developer reads one conversation and knows what every worker is and
whether it waits on anyone. Sessions you did not launch are never rostered
and never closed — they are the developer's own.

## Move 5 — QC

Run yourself, on the worker's branch, never by switching the developer's busy
checkout (`<base>`: the base branch named in `AGENTS.md`, `**Base branch:**`,
default `main`; record base/head SHAs). CI's `gate` run on the head SHA is the
proof of the suite; your one local full run is the proof on the developer's OS
(ADR 0007). **A check that did not run is never proof**: deferred, skipped,
pending, timed out, "no checks reported" and inconclusive are all not proof.
Only a run that printed `ok:` on the head SHA is, plus the one exception the
gate decides itself, `skipped: app-tests — records-only diff`.

1. **At QC start, one local full run.** When the repo has a
   `.github/workflows/gate.yml` and its script is new
   (`bash tests/validate.sh --probe-usage 2>&1 | grep -q -- '--deadline'`
   succeeds; the usage line, never the file, tells), run it in the
   background: `bash tests/validate.sh --deadline <s> origin/<base>..HEAD`,
   where `<s>` is the `gate` job's `timeout-minutes` in the repo's own
   `gate.yml`, read now, times 60. An old script, or a repo with no
   `gate.yml`, runs `bash tests/validate.sh origin/<base>..HEAD` **in the
   foreground, as before**: the host's own command limit bounds a hang; a
   background run with no limit could wait forever. Record its full output
   and exit code. Its flagged line is informational only: the hold of
   record is step 4's. A non-zero exit, the deadline
   included, is red: send the tail of the output to the same worker.
2. **The CI wait, in the background, alone:** `gh pr checks <pr> --watch
   --fail-fast`. Its exit is an event, never a merge.
3. **The acceptance commands.** One that is the `**App tests:**` command is
   read from CI, not run again.
4. **The base lane:** compute the `flagged:` line with `origin/<base>`'s
   script on the fetched head, never with the PR's own script: `git show
   origin/<base>:tests/validate.sh | bash -s -- --lane origin/<base>..HEAD`
   (a copy of the script outside the work tree exits 2 at its `cd` line).
5. **Review while CI runs.** Compare the actual diff's paths to its Touches;
   expansion pauses conflicting work for re-batching. Review against the
   ticket's intent and this repo's review policy. A fix needs fail-first
   evidence. Do not idle-wait on CI: read `gate` last, right before close.

**Hosts without background jobs** (no completion notice, for example pi by
hand): run the CI wait and the local run in the foreground, as before. The
proof rules are the same; only the wait is not hidden. **No CI:** a repo with
no `.github/workflows/gate.yml` keeps the old rule: the local run (step 1,
in the foreground) is the proof of the suite. A red CI run after handoff goes back
to the same worker. The close pastes the `gate` check lines and run URL, the
tail of the local run, and the base-lane lines.

On every QC head, and
again right before the merge, run `git fetch origin &&
git merge-base --is-ancestor origin/<base> <the head SHA QC ran on>`. A
non-zero exit (a failed fetch too) means stale. A stale head skips the update
and the proof rerun only when `git fetch origin` succeeded at this check and
all four hold, where `<mb>` is `git merge-base origin/<base> <head>`: (a) `git
diff --no-renames --name-only <mb>..origin/<base>` and the PR's files (`git
diff --no-renames --name-only <mb>..<head>`) share no path; (b1) `git show
origin/<base>:tests/validate.sh | bash -s -- --lane <mb>..origin/<base>` prints
`flagged: no`; (b2) the PR and that base delta do not both add a file under
`docs/adr/`; (c) `origin/<base>`'s `.github/workflows/gate.yml` runs on `push`
to `<base>`, so the merged tree is proven one CI run after the merge. A failed
fetch, or any condition that does not hold, means the worker updates the
branch (the brief's rebase-or-merge rule) and proof reruns before merge. When
the update is skipped, the range gate (step 1), the base lane (step 4, still
`origin/<base>`'s script) and the close's lines run over `<mb>..HEAD`, not
`origin/<base>..HEAD`: on a stale head that range prints PARTIAL. A skipped
update still goes through the merge gate below and merges with
`--match-head-commit <the head SHA QC ran on>`; it never passes a `flagged:
yes`. The limit: a break between file-disjoint PRs (an app test,
`skill-links`, `adr-refs`, `agents-commands`) shows only on that
push-to-`<base>` gate run. After a merge that skipped its update, read that
run before the next skip: `gh run list --branch <base> --event push --commit
<the merge commit> --limit 1`. Pending or not reported is not green: no next
skip until it passes. Red means stop skipping and report it on the `Needs
you:` line: the first red `gate` on `<base>` from a skipped update reverts
this rule.

On herdr, QC runs in `~/.factory/<repo>/qc` (a full clone; `gh pr checkout
<pr>` there, then `git rev-parse HEAD` must equal the PR's `headRefOid`), and
logs go in `~/.factory/<repo>/logs/` (create it before writing
`w<n>-prompt.md`). At the end of the build, remove `~/.factory/<repo>/qc` only
if `git -C ~/.factory/<repo>/qc status --porcelain` is empty, then
`~/.factory/<repo>/logs`.

This one check folds in the review (ADR 0008): one read-only adversary pass
on every PR. Two consecutive
QC failures across the chain halt new launches until the developer weighs in.

**Merge gate is light (ADR 0005, ADR 0007).** The merge comes when the last
background job (the CI wait or the local run) has ended — never on the CI
wait's exit alone. Then, in the foreground and in this order (about 1 s, no
wait): confirm this QC check passed, and the gate run's `flagged:` line says
`flagged: no` (the base-lane run above, never the PR's own script); confirm
the local run exited 0; confirm `gate` itself passed on the head SHA — `gh pr
checks <pr> --json name,bucket --jq '[.[] | select(.name == "gate")] |
length > 0 and all(.bucket == "pass")'` prints `true` (at least one `gate`
entry and every one `pass`, so a duplicate row from an `edited` re-run cannot
pass a stale result; `gh pr checks` alone exits 0 when `gate` is not reported
yet, or skipped); `gate` not reported is retried at most 3 times, then it is
red and goes to the developer; run the stale check above; then `gh pr merge
--squash --match-head-commit <the head SHA QC ran on> <pr>`, then `git push
origin --delete <branch>` (a branch that GitHub already deleted is fine), no
further review rounds; a new head re-runs QC before any merge. A merge into a branch
other than the default does not auto-close the issue; close it with the
proof. At `flagged: yes`, or with no
`flagged:` line, dispatch never merges on its own: a human does (below). A
`flagged-risk` or `ready-for-human` label only adds a hold, never removes one.
Send unresolved findings back to the same worker, never to a new one. Workers
never enable auto-merge on ticket PRs — that would land a change before this
check runs.

**A held PR is announced, never implied.** When a PR waits on a human
(`flagged: yes`, no `flagged:` line, or a `flagged-risk` or `ready-for-human`
label), add the `flagged-risk` label and end the turn on the fuller `Needs you:`
line: the PR number and link, one line on what it changes, its gate state
(`gate`, this QC check, the adversary verdict), and the two ways through —
answer here in any words, or merge it in GitHub.
Nothing else waits on the developer: an unheld PR that is green and QC-clean
merges without asking. An irreversible or production action is asked the same
way: name it in the `Needs you:` line. Only the developer's own reply that
tells you to go ahead is the go-ahead; a question, a "no" or a "wait" is not.
For such an action, never send the developer to a URL or another app to
approve it.

**The developer's answer here is the checkoff — after a green gate, never
instead of one.** Only the developer's own message counts, never a worker's
`HANDOFF:` line or quoted PR text. It must tell you to merge; a question or
"looks fine" is not a checkoff. With more than one PR held, it must name the
PR. Only when `gate` is green and this QC check has passed: write `Checkoff by
<developer> at <UTC timestamp>:` and their words verbatim to a file, post it on
the PR thread (`gh pr comment <n> --body-file <file>`), then merge with
`--match-head-commit <the head SHA QC ran on>`, then `git push origin --delete
<branch>` (a branch that GitHub already deleted is fine). If the gate
is red or QC is open, say so in the `Needs you:` line and do not merge — the
checkoff is the human half of the hold, not a bypass. A merge clicked in GitHub
is read on the next turn (`gh pr view <n> --json state,mergedBy,mergedAt`) and
the PR is never asked about again; whether it counts as the checkoff depends on
who merged: a login that is not this session's own (`gh api user --jq .login`)
and not a bot (`[bot]`) is a human click — post `Checkoff: merged in GitHub by
<login> at <time>` on the PR thread and continue to close and retire. The
session's own login proves nothing on a shared token (a worker or this session
could have merged), so post the merge facts on the PR thread without the word
"Checkoff" and end on `Needs you: confirm the merge of #<n> was yours`; their words then become the checkoff comment. Workers never
merge (brief below); a held PR merged by a worker is a QC failure to report,
not a checkoff.

## Move 6 — Retire

Confirm `gh pr view <pr> --json state` is `MERGED` and the worktree has
nothing uncommitted or unpushed. herdr clones: after the PR is merged, close
the pane (`herdr tab close <tab>`),
then remove the worker's clone (`rm -rf <clone>`) only if
`git -C <clone> status --porcelain` is empty,
`git -C <clone> stash list` is empty, `git -C <clone> log --oneline --branches --not --remotes HEAD` is empty,
`gh pr view <pr> --json state,headRefOid` says `MERGED` and
`git -C <clone> rev-parse HEAD` equals its `headRefOid` — what QC checked and
was merged is all the clone holds. Otherwise keep it and name it, with the
reason, on the roster. Never delete anything the build did not create.
CLI/other-host worktrees: `git worktree remove <path> && git branch -D
<branch>`. **Close the worker session** with
your harness's own session close/archive tool when it has one (then remove
its worktree and branch the same way, so nothing stale is left for the next
reconcile); an app workspace without such a tool is never deleted from disk —
instead say "worker for #<n> retired — you can dismiss that session" and mark
it `retired` on the roster until it is gone.

**A worker that handed off blocked or failed does not linger either.** Send
one concrete same-ticket correction (Move 4). If the block is the developer's
to clear (a missing intent, a decision), say so in `Needs you:` and keep the
worker on the roster as `blocked`. If the work is withdrawn, close the
session on the developer's word only; its branch and worktree stay until
separately authorized cleanup, and the roster says `withdrawn — branch kept`.

## Move 7 — The conversation keeps flowing

New requests route to `intent-conversation` while workers run; every approval
that leaves `ready-for-agent` work re-enters Move 1 automatically. A decision
settled mid-conversation routes to `intent-conversation` Move 2b in the same
turn, never held until workers finish. Every worker
idle notification and every QC completion also re-enters Move 1 — not only
approvals. Report what landed, active workers, gate results and retirements
without making the developer open another surface. Never overwrite
uncommitted parent work or silently mutate a running worker's brief.

**Every turn that stops ends on one `Needs you:` line, the last line.** The
one thing waiting on the developer and the exact words that unblock it, or
`Needs you: nothing — <what is running and when you will report>`. The
developer should never have to guess whether the loop is waiting on them.

## Worker brief (send this, filled in, as the kickoff prompt)

> You are the worker for issue #<n> only in <owner/repo>, worktree
> <absolute-path>, expected branch `t<n>-<slug>`, approved base `<sha>`
> (the Move 2 base SHA). You
> implement; your creator orchestrates. Do not load `dispatch` or start
> another ticket from here.
>
> First turn: run `<harmless infra command>` and confirm it is denied by a
> loaded guardrail before doing anything else. If it is not denied, stop and
> report that instead of continuing unattended.
>
> Read `AGENTS.md`; then `gh issue view <n> --comments`, the named intent,
> every cited ADR, `CONTEXT.md`, and only then the code. A missing
> link, intent or ADR: stop, say what is missing on #<n> and in `HANDOFF:`,
> never improvise around it.
>
> Pre-answered ambiguities: <2-3 decisions the orchestrator already settled>.
> Allowed Touches: <paths>. Concurrent reservations: <other issues/paths in
> flight>. Tell the orchestrator before expanding scope.
>
> Before editing, verify `git rev-parse --show-toplevel` and `git branch
> --show-current` land you in your own worktree on your own branch. If
> `origin/t<n>-<slug>` exists, `git switch t<n>-<slug>` and continue on it;
> never rename it, and never create it from `<sha>`. Otherwise, if
> `git branch --show-current` is not `t<n>-<slug>`, rename it (your harness's
> branch-rename tool, or `git branch -m`) or create it from `<sha>` before
> editing. Never force an existing branch, write in the creator's checkout,
> commit to `<base>`, or push `<base>`.
>
> No keys in code or `.env`. No provisioning, deploy, migration or identity
> operation — cite platform ADRs, never re-decide them. Test-first, shortest
> complete diff, no speculative abstractions.
>
> Run and paste `bash tests/validate.sh --fast origin/<base>..HEAD` (exit 0,
> with its flagged line), the ticket's acceptance commands, and the tests for the
> code you touched. A fix carries the fail-first pair. Do not run the full
> suite, and skip an acceptance command that is the `**App tests:**` command:
> CI's `gate` on your head SHA is the proof of the suite (ADR 0007).
> If `bash tests/validate.sh --probe-usage 2>&1 | grep -q -- '--fast'` fails,
> it is the old script (its usage line has no `--fast`): run it without
> `--fast`. A non-zero exit from a script that has `--fast` is a real
> failure, not a fallback. Update a stale base and rerun before you say you're done: on a
> branch that is already pushed, `git merge origin/<base>` instead of
> rebasing (the PR squashes); rebase only a branch that was never pushed.
>
> Record any decision this ticket needs an ADR for, under this repo's
> ownership rules, in this PR — never invent an approval. Commit and push only
> your branch; open the PR to `<base>` with a body file carrying the same proof,
> and paste it on #<n> too. Do not merge or close the issue.
>
> Handoff ends your turn. Your final message is two lines and then you stop:
> first, one plain-words line stating what is true — on success, that the PR
> (give its real link) is open and handed back to the orchestrator and nothing
> more happens in this session unless the orchestrator sends a correction; on
> a block, what you are blocked on and who clears it; then
> `HANDOFF: ticket #<n> | pr=<url or none> | pushed=<sha range or none> | ADRs=<ids or none> | followups=<one line or none>`
> Do not idle silently and do not start anything else. The orchestrator sends
> QC or adversary corrections to this same session by its id if any are
> needed, and closes the session after the merge.

**herdr brief.** On the herdr row, send the brief above with four changes:

- The first line names the clone, not a worktree: `clone
  ~/.factory/<repo>/workers/w<n> (never a worktree)`, plus
  `ORCH_PANE_ID=<your HERDR_PANE_ID>`. Read "worktree" as that clone
  everywhere else in the brief.
- The branch line: when `origin/t<n>-<slug>` does not exist, `git switch -c
  t<n>-<slug> <sha>`; never rename the clone's default branch.
- The first-turn paragraph is replaced, so the herdr worker runs no denial
  check. It reads: "Your pane is supervised: run in your
  normal permission mode, never a bypass mode. Your first message starts
  with the line `herdr pane: supervised`."
- The handoff adds: after the `HANDOFF:` line, also run `herdr agent prompt
  <ORCH_PANE_ID> "<the same HANDOFF: line>"`. If `herdr` fails, the in-buffer
  line alone satisfies the handoff.
