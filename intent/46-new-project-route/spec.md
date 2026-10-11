# Spec: the new-project route

**Issue:** #46 · **Intent:** `intent/46-new-project-route/intent.md` ·
**Status:** approved · **ADRs:** none (no new cozyharness ADRs during this work; see Design concerns)

## Problem statement

A developer in an empty folder must get, from one request, a repo that every
plugin skill can work in: tracked on GitHub, protected, with a green gate and
a written merge policy. Today no skill does this, and the skills that run a
project refuse to start, read files that do not exist, or assume the base
branch is `main`.

## Requirements

1. As a developer in an empty folder, I want to say "start a new project",
   so that the repo is set up without me naming files or labels.
2. As a developer, I want at most two questions (owner/name and
   visibility), each with a default, so that setup does not become a form.
3. As a developer, I want existing files never overwritten, so that running
   the route in a half-set-up folder is safe.
4. As `intent-conversation`, I want `AGENTS.md`, `STATUS.md`,
   `CONTEXT.md` and the intent templates present, so that my first move
   (system intent) can run.
5. As `dispatch` and `factory-orchestrator`, I want a gate
   (`tests/validate.sh`), a review policy (`REVIEW.md`), the full label set
   and a base-branch setting, so that QC and merges work on day 1.
6. As the operator, I want the merge policy written in the new repo and
   enforced by a ruleset and a required CI check, so that auto-merge on green
   is safe; if enforcement is not available, the policy starts closed.
7. As a herdr orchestrator, I want a worker template that reads the suite
   from `AGENTS.md` and opens a PR on `t<n>-<slug>`, an adversary agent, and a
   guardrail in the new repo, so that workers run unattended and correctly.
8. As a developer who says "I want an app that…" in an empty folder, I want
   `intent-conversation` to offer `new-project` instead of stopping.
9. As a maintainer of cozyharness, I want one base-branch setting read by
   the gate, `dispatch` and `intent-conversation`, so that work on a
   long-lived branch other than `main` targets that branch and closes
   validly.

## Design concerns

- **Branch and release model (operator decision 2026-10-04, option A).**
  `cozyharness_full_workflow` is cut from `claude-harness` at `5af43f5`
  (v1.4.2); ruleset: no deletion, no force-push, PR required.
  `claude-harness` stays the corporate production dependency: patch-only
  (1.4.x), ruleset no deletion and no force-push. Flow is one-way:
  `main` → `claude-harness` → `cozyharness_full_workflow`, by reviewed merge
  PRs. 1.5.x tags are cut from `cozyharness_full_workflow` only.
- **No new cozyharness ADRs during this work.** ADR numbering is contiguous
  per branch, and #39 takes 0005 on `main`. This rule lives here until an
  ADR number is free on all branches. Plugin text and templates do not cite
  cozyharness ADRs by number (the `adr-refs` check scans `plugin/`).
- **Base branch (#47).** One `**Base branch:**` line in `AGENTS.md`
  (default `main` when absent). The gate's `--lane` PARTIAL check reads it;
  the env var `LANE_TARGET` only overrides it. `dispatch` and
  `intent-conversation` read it for worktree base, PR base and QC range.
  Until #47 merges, close with `origin/main..HEAD`; after it, with
  `origin/cozyharness_full_workflow..HEAD`.
- **`new-project` skill (#49).** A separate skill, not a move inside
  `intent-conversation`. Moves: ground (read-only), ask (at most two
  questions; owner defaults from `gh api user`, asked only when
  `gh api user/orgs` is not empty), scaffold, GitHub, verify and hand off.
  One route for a brand-new folder and an existing repo (operator direction
  on #46, 2026-10-06): HEAD without commits → commit to `main`,
  `gh repo create`, labels and a ruleset; HEAD with commits → commit to
  branch `adopt-engineering-workflow` and open a PR into the default branch,
  never writing to that branch or its protection. The scaffold never
  overwrites: it appends one marked block to an existing `AGENTS.md`,
  `CLAUDE.md` and `.gitignore`, and skips every other existing file, so a
  re-run writes only what is missing. One-line stops: inside another repo,
  tracked changes, an unborn HEAD with other refs, a checked-out branch that
  is not the origin's default. With an `origin` and nothing left to write:
  the one-line `cmu` offer.
- **Scaffold.** Templates live in the plugin (pinned with the tag) and are
  found relative to the skill's own `SKILL.md`, not a host variable. Files:
  `AGENTS.md` (commands, `**Base branch:** main`, tracker, labels, read
  order, worker kind, policy pointer), `CLAUDE.md`, `STATUS.md`,
  `CONTEXT.md`, `REVIEW.md`, `README.md`, `intent/TEMPLATE.md`,
  `intent/TEMPLATE-spec.md`, `docs/agents/triage-labels.md`,
  `docs/agents/issue-tracker.md`, `docs/engineering-workflow.md` (pointer
  to the skill plus this repo's merge policy), `docs/adr/` with the new
  repo's first record (adopting the workflow and its merge policy: hold
  `tests/validate.sh`, `.github/workflows/**`, `.githooks/**`; everything
  else merges on green with review owed; fails closed),
  `tests/validate.sh` (shape checks, `--lane` with the light set copied
  unchanged, worktree-safe root resolution per #45, `--witness`, a
  `# scaffolded from engineering-workflow--vX.Y.Z` stamp),
  `.github/workflows/gate.yml` (on pull request and on push to `main`),
  `.gitignore` (incl. `.factory/`). Not created: `SYSTEM-INTENT.md`.
- **GitHub moves.** Initial commit, then `gh repo create --source . --push`;
  labels `needs-triage needs-info ready-for-agent ready-for-human wontfix
  ticket flagged-risk`; ruleset on `main`; required status check after the
  push run; read back. If the ruleset is not enforced (private repo on a free
  plan), the policy doc records the closed state (pre-merge checkoff).
- **`.factory/` is local, ignored, recoverable state only.** A build's
  design source is the design issue's `spec.md` (ADR 0002);
  `factory-orchestrator` reads `.factory/design.md` only when present (#48).
- **herdr day 1 (#48, #50).** Worker template reads the suite from
  `AGENTS.md ## Commands`, works on `t<n>-<slug>`, opens a PR to the base
  branch; worker kind comes from `AGENTS.md`. The scaffold ships the
  adversary agent and a guardrail (pi extension and a Claude PreToolUse
  deny hook) so `dispatch` Move 3's harmless-denial proof can pass.
- **Routing (#51).** `intent-conversation`'s refusal offers `new-project`;
  Phase 0 in the synced trio points to `new-project`.

## Constraints

### System

- Bash, git, `gh`, python3 stdlib only. The scaffolded gate runs offline.
- Skill edits land in `plugin/skills/` with byte-identical `.claude/skills/`
  copies (plus `.agents/skills/` for `factory-orchestrator`).
- Tickets `t<n>-<slug>` branch from and PR into
  `cozyharness_full_workflow`. Lane T2. PRs that change
  `tests/validate.sh`, `.github/workflows/**` or `.githooks/**` are merged by
  Sean after the orchestrator's OK; the orchestrator merges the rest.

### UX

- The developer sees at most two questions, never a template or a file list
  as a form. The route ends with one line handing to the system intent.

### Security

- The route creates a remote repository and a ruleset: outward-facing,
  confirmed by the developer's request and the visibility answer.
- No secrets are written. Developer words never reach a command line.
- The guardrail and the hold list protect the files that check other files.

## Testing decisions

- Gate checks and witnesses in cozyharness `tests/validate.sh`; every new
  check or classifier branch is admitted with a fail-first witness.
- #49 witness: scaffold into a temp dir, run the scaffolded gate → PASS;
  delete one required file → FAIL.
- Behaviour proof: a headless session in an empty temp folder with the
  GitHub moves skipped, transcript pasted; the live proof on `fit_cozy`
  in #52.

## Out of scope

- App stack, hosting and environments (app ADRs and tickets).
- herdr pane setup (owned by `factory-orchestrator`).
- Porting to `main` (adoption item on #35 after #52).

## Open questions

None blocking.
