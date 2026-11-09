# Proposal: a verification layer at the PR

**Status:** proposal only. No code, skill or gate changes come with it.

## Why

The gate checks files, and every agent-written test is written by the same
author as the code. Nothing in the workflow makes an agent use the product it
changed. In the 2026-11 evaluation, the plugin's live workflow cost 1.5x to 4.1x
against a 1.25x budget, so a new layer has to earn its place and cannot run on
every turn.

## The layers

Each layer runs once per PR. A human only appears in the last one.

| Layer | What it answers | Runs | Status |
|---|---|---|---|
| Tests and `tests/validate.sh` | Does the code do what its tests say? | Every PR (already `gate`) | Exists |
| Real-behaviour verification | Does the product actually work when used? | PRs that touch a mapped feature | Proposed |
| Decision-conflict check | Does this cross an earlier decision? | Before building and in the PR's adversary pass | Branch `windows/lean-decision-conflict-check` |
| Human | Should this merge at all? | The held list and irreversible actions only | Exists (ADR 0005) |

## Real-behaviour verification

This follows Lauren Tan's pstack approach as described in secondary sources.

- **The agent drives the real product.** It starts the app, goes to the changed
  feature, uses it and reads the result, instead of trusting its own tests.
- **Evidence is attached to the PR.** A screenshot, a recording, or the
  structured output of the run. This would replace the UI "preview proof" that
  Deploy already asks of consumers.
- **A feature map is maintained.** One short markdown entry per user-facing
  feature: how to reach it, how to control it, known traps. The app stays the
  source of truth, and a PR that changes a feature updates its entry.

It applies to consumer apps. This repo has no runtime, so it would not run here.

## Keeping it within 1.25x

- It runs at the PR, never per turn, and only when the diff touches a mapped
  feature. Small changes without one skip it.
- It adds no approval and no question. A failure sends the work back to the
  agent, and only the held list reaches a human.
- The map is updated in the PR that changes the feature. pstack's recommended
  daily refresh is left out as a recurring cost.
- It should be measured before adoption: the feature-request and session-chain
  cases, with the layer on and off, against the 1.25x budget. If it goes over,
  narrow the trigger or drop it.

## What the sources do and do not support

The sources read were mostly secondary, and none of them states a merge policy,
so the merge rule above is this repo's own (ADR 0005), not something pstack or
Anthropic prescribes.

- **pstack:** read through web summaries and commentary only. Tan's own guide
  was not opened, and her results are self-reported.
- **Anthropic's AI-native SDLC playbook:** about the first half was read
  directly, including "A skill is an advisory control while a hook is the
  deterministic layer behind it." An automated summary of the rest mentions
  branch protection and a pass-rate merge check. That part was not read, so
  check it before relying on the statement about merge policy above.

## Decision wanted

Whether to build real-behaviour verification for consumer apps, starting with
one app and the measurement above. Until then, nothing changes.
