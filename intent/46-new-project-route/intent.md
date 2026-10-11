# Intent: one request starts a brand-new app repo under the workflow

**Issue:** #46 · **Status:** approved · **Type:** feature

## Problem

The engineering-workflow plugin can run a project but cannot start one. In a
brand-new folder (live case `~/dev/fit_cozy`, plugin v1.4.2 pinned) the first
request stalls: `intent-conversation` stops without `STATUS.md` and
`AGENTS.md`, there are no intent templates, no gate, no merge policy, no
labels and no branch protection. The herdr worker template fits only the old
pi factory project, and a new repo has no adversary agent and no guardrail
for unattended workers. The skills also hard-code `main` as the base branch,
so work on any other long-lived branch targets the wrong branch.

## Desired outcome

One plain-language request ("start a new project") turns an empty folder into
a protected GitHub repo with a green gate that every plugin skill and herdr
orchestration can work in, then hands to `intent-conversation` for the
system intent. It is released as 1.5.0 from `cozyharness_full_workflow` and
proven on `fit_cozy`.

## Status

**Operator decision (2026-10-05):** this branch stops after #49. #50, #51
and #52 are closed as not planned and move to `main` (after the #35
catch-up). #49 covers a brand-new folder and an existing repo (by PR);
the survey of an existing repo into first issues is a later main ticket.
No 1.5.0 release from this branch.

## Scope

- One base-branch setting read by the gate, `dispatch` and
  `intent-conversation` (#47).
- A host-neutral herdr worker template in `factory-orchestrator` (#48).
- The `new-project` skill, its templates in the plugin, and a witness that
  the scaffolded gate passes (#49).
- Adversary agent and guardrail in the scaffold (#50).
- Routing from `intent-conversation` and Phase 0 to `new-project` (#51).
- Release 1.5.0 and the `fit_cozy` proof (#52).

## Non-goals

- Choosing an app's stack, hosting or dev → test → prod pipeline: app
  decisions, filed through `intent-conversation` in the app repo.
- Porting to `main`: an adoption item on #35 after #52.
- New cozyharness ADRs during this work (see the spec).

## Acceptance criteria

- Every child ticket #47–#52 is closed with pasted proof.
- In an empty folder, "start a new project" produces a repo where
  `bash tests/validate.sh` exits 0, the ruleset reads back, and
  `intent-conversation` starts its first move.
- Tag `engineering-workflow--v1.5.0` exists on `cozyharness_full_workflow`
  and `fit_cozy` runs on it.

## System-intent alignment

Serves enduring purpose 5 (the process is portable and lives in the repo):
a new repo gets the whole loop from one request, not from hand setup.

---

_`plan.md` is **optional** in this directory: create it only for a
multi-ticket build with a real order or blocking story to record. When
present it is the ticket/ADR **execution sequencing** — not the agent's
per-session plan-before-code, which is an always-kept coding practice and
never a file here._
