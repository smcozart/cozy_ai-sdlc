# System Intent — The Harness

**Status:** approved · **Origin:** issue [#2](https://github.com/smcozart/cozy_ai-sdlc/issues/2)

## Why this system exists

Software teams increasingly delegate execution to AI agents, but the failure
mode is not the agents — it is the missing scaffolding around them: intents
nobody wrote down, decisions that died in chat, work "done" without proof.
The Harness exists to make the human-governed loop the default: **humans
instigate, direct, and govern; agents take the center of the loop.**

## Enduring purpose

1. Every unit of work starts from a written intent (the "why") that a human
   has approved — no intent, no work.
2. The tracker (GitHub Issues) is the system of record: issue numbers join
   humans, sessions, and machines; blocking edges and triage labels decide
   flow.
3. Proof replaces claim: closing work requires pasted verification output.
4. Hard-to-reverse decisions are recorded as versioned ADRs in the same
   commit as the change.
5. The whole process is portable — it lives in the repo, not in any one tool,
   so any agent harness can take the center of the loop.

## What this system is not

- Not a project-management framework for humans-only teams.
- Not a replacement for engineering judgment — the contracts make judgment
  auditable, they don't remove it.
- Not tool-locked: Claude Code, pi, and Copilot are hosts, not the product.

## Finish line for v1

v1 is done when both hold:

1. The six-stage loop has run end to end, from intent to a merged and proven
   PR, on two real product repos: cozy_view (done: 19 tickets, 45 PRs from
   2026-10-12 to 2026-10-16) and cozy_fit.
2. During the cozy_fit run, the developer makes fewer corrections per session
   than in the week of 2026-10-12 (9 in 5 sessions), as cozy_view measures.

## How the system changes

Before and after v1, a change to the system gets in only when one of these
holds:

- cozy_view shows the deviation it fixes at least 5 times in at least 2
  sessions;
- a real run stalled on it (the session id is on the issue);
- a check or a merge hold gives a wrong result (shown by a fail-first witness).

Anything else goes on the one ledger issue, not into a new issue. A change
that adds a skill, a gate check or a template file names what it replaces, or
why nothing can be removed.

## Alignment

Every work-item intent (`intent/<issue-number>-<slug>/intent.md`) is checked
against this document during Plan. An intent that conflicts with system
intent either justifies an amendment to this file or gets rewritten.
