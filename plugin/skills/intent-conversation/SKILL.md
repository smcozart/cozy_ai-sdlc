---
name: intent-conversation
description: >
  Turn what the developer says about their app into the records the loop needs —
  the app's system intent, an issue with its intent file and its lane, a
  decision's ADR, spec section or ticket body, the approval comment, and the
  wrap-up handoff. Use when the developer describes a feature, a fix or a UI
  change in plain words ("add", "fix", "change", "I want", "we need", "can
  you"); when they settle a decision ("let's go with", "lock that in", "we
  decided"); when they keep filing while other work is in flight ("while
  that's running", "also need"); when the app's `SYSTEM-INTENT.md` is missing
  or still has placeholder sections; when the developer approves with "go",
  "build it", "do it", "yes, go ahead"; and when they wrap up with "I'm done",
  "done for today", "wrapping up", "let's stop here", "hand off".
---

**Companion skill:** `dispatch` ships alongside this skill (ADR-006 child 3) — automatic
one-worker-per-ticket dispatch from `ready-for-agent` issues, cross-referenced here by name only,
never a path.

# The intent conversation

The developer talks; the records appear. They never see a template, never see a
menu, never see a phase name. Use the app's `CONTEXT.md` vocabulary when it
exists — its terms are the only words for the things it names. ("Developer" here
means the person at this seat, whatever `CONTEXT.md` calls them.)

**Only in a repo with `STATUS.md` and `AGENTS.md`.** Otherwise say in one line that the
repo is not shaped for tracking and stop — file nothing, create no labels.

**Never ask what the repo can answer.** Read `STATUS.md`, `SYSTEM-INTENT.md`,
`CONTEXT.md`, `AGENTS.md` and the tracker before you open your mouth. At most
one question per turn, and only when nothing in the repo settles it.

**Never put the developer's words on a command line.** Titles, bodies and
comments go through files you write with the Write tool (`--body-file <file>`,
`--title "$(cat <file>)"`). A quote, a backtick or a `$(` in what they said must
land in the record verbatim, never in the shell.

**Every turn that stops ends on one `Needs you:` line — the last line, always.**
It names the one thing waiting on the developer and the exact words that
unblock it (`Needs you: approve #7 — say "go"`), or says `Needs you: nothing —
<what is running and when you will report>`. A PR held for a human gets the
fuller form in `dispatch` Move 5. Never bury the ask mid-message, never end on
a status, never end on a question the repo could have answered.

---

## Move 1 — complete the system intent

Trigger: `SYSTEM-INTENT.md` is absent, or a section under it is empty or still
carries placeholder text.

The section headings of this plugin's own `SYSTEM-INTENT.md` are the questions.
Ask them one at a time, in plain language, **only for the sections that are
empty or placeholder**:

| Section | What you ask |
|---|---|
| Why this system exists | "In a sentence or two, what is this app, and what problem does it solve for the business?" |
| Users | "Who uses it day to day, and what are they trying to get done when they open it?" |
| Surfaces | "What will people actually see and touch: screens, reports, an API, a scheduled job, data?" |
| Enduring purpose | "As this app grows and changes, what should always stay true about it? For example, the totals always match the ledger, or only HR can ever see pay." |
| Non-goals | "What should this app never do, or never turn into? Include things people might ask for that belong somewhere else." |
| How we know it is working | "A few months in, how would you know it's working? What would you look at, or hear from the people using it?" |

Write their answers into `SYSTEM-INTENT.md` in their own words, one section per
heading, with a `**Status:** stated by <developer>, <date>` line at the top.
Then say in one line that it is written and what it says the app is for.

Do not show the headings as a form, do not paste the template, and do not ask
about a section the repo already answers.

---

## Move 2 — a request becomes an issue and its intent, in one step

Trigger: the developer describes something they want, in their own words.

This is **one step**, not a conversation. Run `gh label list` before each
`gh issue create`; when it lacks any of `needs-triage`, `ready-for-agent`,
`needs-info`, `ticket`, create the missing ones (`gh label create <name>`).
`gh issue create` fails outright on an unknown label, and the check is cheap
and idempotent.

Write the title (their words, trimmed to a line) and the body to files, then:

```bash
gh issue create --title "$(cat <title-file>)" --label needs-triage,ticket --body-file <body-file>
```

Body: **problem**, **desired outcome**, **scope** — their words first, plus what
the repo already tells you (the surface it touches, the file or screen by name,
the app's own vocabulary).

Then write `intent/<n>-<slug>/intent.md` from `intent/TEMPLATE.md`, filled in
from the same words, with `**Issue:** #<n>` and `**Status:** draft`. The issue
number only exists after the create, so cite the intent path in the body with
`gh issue edit <n> --body-file <file>` once the folder is named.

Also write a `**Touches:**` line — a JSON array of repo-relative paths/globs
this work will change (`["backend/src/routes.ts", "backend/test/**"]`). Use
what the repo already tells you about the surface named; when you cannot
bound it yet, leave it empty or omit it rather than guess — `dispatch` reads
a missing or unbounded list as "unknown" and runs that ticket alone.

**An issue never stands without its intent.** If anything after the create
fails (the folder exists, the write is denied, the session is cut), comment on
the issue in one line saying the intent file is missing and must be written
before the work starts, and say the same to the developer. Leave `needs-triage`
as it is — `needs-info` means the reporter owes an answer, and here they do not
(`docs/agents/triage-labels.md`). Do not say "filed" until the intent file is on
disk.

Say which lane it will likely take — the gate computes the lane
(`tests/validate.sh --lane`, escalate-only); this is a hint: one or two files,
docs-only or internal, no protected surface → "likely T1 light"; anything else →
"T2 heavy".

Reply in **one sentence**: the issue number and the lane. For example:

> Filed #47 — a fleet-utilisation column on the dashboard; intent is in
> `intent/47-fleet-utilisation-column/intent.md`. Likely T1 light.

Ask at most one question, and only if the repo cannot answer it.

**Intake never waits.** Filing is never gated by running workers, an open
blocker, a PR awaiting QC, or a foundation ticket in flight — file the next
idea the moment it is said, in the same turn. "And Y depends on X" is filed
blocked: write the tracker's own dependency edge (`gh api -X POST
repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by -F issue_id=<numeric
id of the blocker>`, the form `dispatch` Move 1 reads) **and** a `Blocked by:
#<m>` line in the body (what `dispatch` Move 3 reads) — both, always; the body
line alone is invisible to `dispatch` and would launch the blocked ticket
early. If filing this idea requires a foundation ticket that does not exist
yet, file it too, say so in one line, and keep taking input.

---

## Move 2b — a decision becomes a record

Trigger: the developer settles something in conversation — "let's go with
X", "lock that in", "we decided", or a direct answer to the session's own
question.

Route it before the next question, in the same turn:

| What was settled | Where it lands |
|---|---|
| A hard-to-reverse or authority rule (who decides, which queues exist, who may assign) | A new ADR, this repo's frontmatter and status-history rules |
| A requirement or design detail | The approved spec's matching section |
| Detail that belongs to one ticket (columns, a saved view, a permitted action) | That issue's body |

**Never switch the developer's own checkout** (`dispatch` Move 5's rule) to
write a record. On first use this conversation: `git fetch origin`, then
create one per-conversation records worktree: `git worktree add
.factory/records/<YYYY-MM-DD> -b records-<YYYY-MM-DD> origin/main` — the
fetch first so the branch is never cut from a stale `main`. If that branch
name already exists (a prior conversation today, or this one resuming after
a merge), suffix `-2`, `-3`, … and open a fresh worktree there; never reuse a
worktree or branch whose PR already merged. Write the file there — through
files you write, never the developer's words on a command line — commit and
push after every decision, and keep **one open PR** to `main` that
accumulates this conversation's records, with a `Records for: #<n> #<m>`
line in the commit message and PR body naming every issue a record
references. Reply in one line once the push lands: "Recorded: ADR-005
priority authority; spec §Design concerns; #6 body (PR #n)" — then ask the
next question.

The developer's in-conversation approval of the decision is the approval of
the record; no separate sign-off. Run Move 5 QC (`dispatch`) on the records
PR yourself and merge it — before labelling a ticket that depends on a
record in it, at wrap-up (Move 4), or when asked. Its lane is the gate's: ADR
and spec edits sit outside the light set, so T2 — one read-only adversary
pass, folded into that QC. Once it merges, retire the worktree and branch
(`dispatch` Move 6) rather than leaving it for reuse; the next decision opens
a fresh one. If the record's ticket is already in flight (a worker holds it),
also comment the record's PR link on that issue in one line, so its worker
and QC read it without waiting on this PR to merge.

Never park a settled decision in chat. In particular, never say any of:

> - "captured in this conversation only"
> - "finish mapping [each area / first], then update [the relevant existing
>   issue/spec] once"
> - "I have not created or edited issues [as a plan]"

A batch update is filed only when the developer asks for one.

---

## Move 3 — "go" is the approval, and the comment comes first

Trigger: "go", "build it", "do it", "yes, go ahead".

Before anything: the intent file exists and cites this issue, and the issue has
no open blockers (`gh issue view <n>` — a `Blocked by:` line names them), and it
is neither closed nor labelled `wontfix` — if it is, someone took it off the
frontier deliberately; say so in one line and do not label. **No open records
PR names this issue** (Move 2b's `Records for:` line) — merge that PR first,
so the worker starts from the record, not before it. If the
intent still carries an open question, ask it now — one question — and put the
answer (or their "go anyway") in the same comment. If a precondition fails, say
so in one line and do not label.

Write the approval to a file — `Approved by <developer> at <UTC timestamp>:`
then their words verbatim — and post it **before** the label, always in this
order:

```bash
gh issue comment <n> --body-file <file>
gh issue edit <n> --add-label ready-for-agent --remove-label needs-triage
```

The comment is the approval record. **Never apply `ready-for-agent` without it.**
If the comment fails, stop and say so — do not label. If the comment succeeded
and the label command then fails, say so in one line: the approval stands on the
issue, the label is not set, and it is applied on the next "go". Do not retry
silently, and do not report it as dispatchable.

Then say in one line that it is approved and dispatchable, and load the
`dispatch` skill now — approval is the gate, and dispatch is automatic from
here: it finds this issue and any other `ready-for-agent` work on its own,
without the developer saying "go work these".

---

## Move 4 — wrap-up writes the handoff

Trigger: "I'm done", "done for today", "wrapping up", "let's stop here", "hand
off" — or context running long.

Write `handoffs/<YYYY-MM-DD>-<slug>.md` (create the folder if the app lacks it;
never overwrite an existing note) with three blocks:

- a **verify-first** block of the commands that re-establish the state (the
  commands are the truth; the note is a snapshot),
- **where we are**,
- **what remains** — in order, with blockers named.

Tag it `#handoff` so the next session's grounding finds it. The grounding reads
the newest note by file name and skips any name it does not recognise, so keep
the date prefix and hold the slug to lowercase ASCII letters, digits and
hyphens. When no handoff note exists for a session that stopped some other
way, `/cmu` reconstructs the same pickup from the tracker and git instead.
Then say in one line that
it is written, and stop.
