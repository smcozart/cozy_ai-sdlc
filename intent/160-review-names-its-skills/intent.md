# Intent: review instructions name the skill they mean

**Issue:** #160 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/REVIEW.md", "REVIEW.md", "docs/engineering-workflow.md", "README.md"]`

## Problem

"The `code-review` skill's two axes" (template `REVIEW.md:25`, root `REVIEW.md:26`, `docs/engineering-workflow.md:322`, `/code-review` at `:419`) resolves to Claude Code's built-in `/code-review`, a bug hunt. The two axes are `mattpocock-skills:code-review`. The Bugs and Security passes name no tool.

## Desired outcome

The two axes name `mattpocock-skills:code-review`; the Bugs pass names the built-in `/code-review`, the Security pass `/security-review`; the adversary pass is unchanged.

## Scope

The four files above; `README.md` only as the sync rule requires.

## Non-goals

Any change to the passes, severity, or lane sizing.

## Acceptance criteria

- No review instruction in the four files says "the `code-review` skill" without the `mattpocock-skills:` prefix.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0.

## System-intent alignment

A review instruction an agent can follow without guessing which skill is meant.
