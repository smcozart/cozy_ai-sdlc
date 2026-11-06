# Intent: a bug report or "file an issue" triggers intent-conversation

**Issue:** #162 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/skills/intent-conversation/SKILL.md"]`

## Problem

"file an issue for this bug: the login button does nothing on Safari" fired no skill (probe P2); the model ran `gh` itself, so no intent file. Filing a fix as an issue with its intent is `intent-conversation`'s stated job; its triggers lack "file an issue" and "bug".

## Desired outcome

In a shaped repo, a bug report or an explicit request to file an issue triggers `intent-conversation`.

## Scope

The skill's `description` triggers only.

## Non-goals

The unshaped-repo guard (it still refuses).

## Acceptance criteria

- The P2 prompt, run in a scaffolded repo, fires `ai-sdlc:intent-conversation`.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0.

## System-intent alignment

Every request becomes an issue with its intent, including the ones phrased as bugs.
