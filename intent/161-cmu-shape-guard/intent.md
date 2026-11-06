# Intent: cmu stops in one line in an unshaped repo

**Issue:** #161 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/skills/cmu/SKILL.md"]`

## Problem

In a folder with no `AGENTS.md`/`STATUS.md`, "catch me up" fired `cmu`, which fetched and ran three Bash rounds, then hit max-turns with no answer (probe P5, Windows 11, ai-sdlc 1.8.1).

## Desired outcome

Without `STATUS.md` and `AGENTS.md`, `cmu` says in one line that the repo is not shaped for tracking and stops: no fetch, no reads.

## Scope

One guard line in `cmu/SKILL.md`, in the `intent-conversation` wording.

## Non-goals

`cmu` in a shaped repo.

## Acceptance criteria

- The same probe in the same folder ends with the one-line refusal and no `git fetch`.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0.

## System-intent alignment

A skill that cannot do its job says so at once instead of spending the session.
