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

## Alignment

Every work-item intent (`intent/<issue-number>-<slug>/intent.md`) is checked
against this document during Plan. An intent that conflicts with system
intent either justifies an amendment to this file or gets rewritten.
