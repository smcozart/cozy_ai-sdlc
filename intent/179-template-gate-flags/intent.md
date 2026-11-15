# Intent: the scaffolded AGENTS.md documents the gate's --fast and --deadline

**Issue:** #179 · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/AGENTS.md", "intent/179-template-gate-flags/**"]`

## Problem

`plugin/templates/new-project/files/AGENTS.md` lists the Test gate's modes
but not `--fast` or `--deadline <s>`, which 1.9.0 added (#176, ADR 0007).
Every repo scaffolded from the template starts without them. The cozystudio#75
adversary found it; cozystudio fixed its own copy in cozystudio#77.

## Desired outcome

The template's Test gate bullet reads
`tests/validate.sh [--fast|--deadline <seconds>] [<range> [<pr-body-file>]]`
and states, one line each, in the words of the template script's header
(`plugin/templates/new-project/files/tests/validate.sh` lines 7-8): `--fast`
runs every check but `app-tests`, which prints
`deferred: app-tests — CI gate is the proof`; `--deadline <s>` fails
`app-tests` at `<s>` seconds and kills its whole process group. CI passes
neither.

## Scope

- The one Test gate bullet in the template `AGENTS.md`.
- Any file a gate check requires to change with it (none expected).

## Non-goals

- This repo's root `AGENTS.md` (same gap; a separate decision).
- The template script and `gate.yml`: no change.

## Acceptance criteria

- `grep -F -- '--fast' plugin/templates/new-project/files/AGENTS.md` and the same for `--deadline` exit 0.
- `bash tests/validate.sh --fast origin/main..HEAD` exits 0 (`agents-commands` and `template-gate-parity` included); CI `gate` and `template` jobs are green.
- A scaffold from the template still passes its own gate: the `template` CI job.

## System-intent alignment

Keeps the scaffolded contracts in step with the scaffolded gate.
