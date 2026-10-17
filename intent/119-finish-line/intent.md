# Intent: the AI-SDLC has a finish line and changes only on evidence

**Issue:** #119 · **Status:** approved · **Type:** system-change

**Touches:** `["SYSTEM-INTENT.md"]`

Approved by Sean, 2026-10-16: "go A, use your finish line draft".

## Problem

The system has purposes but no finish line, so it can grow without a stopping point. Since 2026-10-10, 30 issues were opened and 10 closed; 8 LOW follow-ups sit unworked; skills grew from 417 to 1,356 lines in 6 days. cozy_view shows the core loop earns its place and does not drift. The risk is growth around it.

## Desired outcome

`SYSTEM-INTENT.md` states when v1 is done and the evidence a change needs to get in.

## Acceptance criteria

- `SYSTEM-INTENT.md` has `## Finish line for v1` and `## How the system changes`.
- `tests/validate.sh` passes on the range.

## System-intent alignment

An amendment to this file, as its Alignment section allows.
