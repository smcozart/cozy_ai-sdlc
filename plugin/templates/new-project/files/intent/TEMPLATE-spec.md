# Spec: <one-line outcome>

**Issue:** #<issue-number> · **Intent:** `intent/<issue-number>-<slug>/intent.md` ·
**Status:** draft | approved · **ADRs:** <NNNN-slug, or "none">

Copy this file to `intent/<issue-number>-<slug>/spec.md` — always a sibling of
the work-item intent, named exactly `spec.md`. The issue body links to the
spec by path; the spec links back to the issue and intent here in the header.
Never copy the spec into the issue body.

## Problem statement

The problem from the user's perspective. One short paragraph; the intent
already carries the full "why" — don't restate it, sharpen it into what this
spec must satisfy.

## Requirements

Numbered user stories: `As an <actor>, I want <capability>, so that
<benefit>`. Extensive — this is the list the tickets and the proof are graded
against. Use the vocabulary of `CONTEXT.md`.

## Design concerns

The decisions made in designing the solution:

- Modules built/modified and their interfaces (no file paths, no code —
  exception: a prototype snippet that encodes a decision more precisely than
  prose, trimmed to the decision-rich parts)
- Seams where the feature will be tested — prefer existing seams, the highest
  seam possible; ideal count is one
- Schema changes, API contracts, specific interactions
- ADRs this design follows, and any new ones it requires (contradictions with
  existing ADRs must be named explicitly, not silently overridden)

## Constraints

### System

Hard limits the design must respect: performance budgets, platform targets,
dependency rules (stdlib first), what must stay portable.

### UX

What the user sees, and the states that must never occur (empty states, error
surfaces, accessibility basics).

### Security

Trust boundaries crossed, validation points, secrets, permissions. An empty
section is a claim — if truly nothing applies, write "none: <why>".

## Testing decisions

What makes a good test here (external behavior, not implementation), which
modules get tested, prior art in the codebase to follow.

## Out of scope

What this spec deliberately does not cover, and where it belongs instead.

## Open questions

Unresolved questions, each with an owner and whether it blocks Build.
Approved specs have no blocking open questions left.

---

## Worked example (abbreviated)

```md
# Spec: Design-stage contract

**Issue:** #3 · **Intent:** `intent/3-design-stage/intent.md` ·
**Status:** approved · **ADRs:** none

## Problem statement

Design is under-specified: agents reaching Build cannot tell what a spec
contains, where it lives, or when a decision needs an ADR.

## Requirements

1. As a Build agent, I want a spec at a predictable path, so that I can
   onboard without chat history.
2. As a maintainer, I want the spec linked by issue number, so that the
   tracker stays the system of record.
3. …

## Design concerns

- Spec lives at `intent/<n>-<slug>/spec.md`, sibling of the intent.
- Seam under test: the workflow doc itself — a fresh agent reads it and
  produces a conforming spec.

## Constraints

### System
- Everything must live in the repo; no tool-locked state.

### UX
- A fresh agent must reach full context in one read order (issue → spec →
  ADRs → CONTEXT → code).

### Security
- None: docs-only change, no trust boundary crossed.

## Testing decisions

Proof = `git diff --stat` of the landed artifacts pasted into #3, plus the
sync rule check: workflow doc, plugin SKILL.md, README changed in one commit.

## Out of scope

Build-phase worker prompt templates (orchestrator's `.factory/` files).

## Open questions

None blocking.
```
