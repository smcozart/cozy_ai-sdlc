# Intent: review instructions name the skill they mean

**Issue:** #160 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/REVIEW.md", "REVIEW.md", "docs/engineering-workflow.md", "README.md"]`

## Problem

"The `code-review` skill's two axes" (template `REVIEW.md:25`, root `REVIEW.md:26`, `docs/engineering-workflow.md:322`, `/code-review` at `:419`) resolves to Claude Code's built-in `/code-review`, a bug hunt. The two axes are `mattpocock-skills:code-review`. The two axes name no plugin, so an agent can run the wrong skill.

## Desired outcome

The two axes name `mattpocock-skills:code-review`. The Bugs, Security and Compliance passes and the adversary pass are unchanged: no tool is named for them, and no review run is added.

## Scope

The four files above; `README.md` only as the sync rule requires.

## Non-goals

Any change to the passes, severity, or lane sizing. Binding the Bugs and Security passes to the built-in `/code-review` and `/security-review`: each adds a model run per PR, `/code-review` repeats the adversary pass, and both are Claude Code only (Sean Cozart, 2026-11-14, SME review item 5).

## Acceptance criteria

- No review instruction in the four files says "the `code-review` skill" or names `/code-review` for the two axes without the `mattpocock-skills:` prefix.
- No review instruction in the four files adds a `/code-review` or `/security-review` run.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0.

## System-intent alignment

A review instruction an agent can follow without guessing which skill is meant.
