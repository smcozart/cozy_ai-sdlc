# Adopt the engineering workflow and its merge policy

**Issue:** none (repo creation, {{DATE}}) · **Status:** accepted

This repo runs the `ai-sdlc` plugin's six-stage loop
(v{{PLUGIN_VERSION}} at creation): GitHub Issues are the tracker, intents and
specs live in `intent/<n>-<slug>/`, decisions are ADRs here, and
`tests/validate.sh` is the gate. Merges follow one policy, written in
`docs/engineering-workflow.md` Deploy: a diff that touches
`tests/validate.sh`, `.github/workflows/**` or `.githooks/**` is held for a
human, because those files check every other file (the `flagged:` line of
`tests/validate.sh --lane` is the one machine-readable source); everything else merges on
a green gate, with a review owed after the merge on the files that steer
agents (skills, `docs/adr/`, `docs/engineering-workflow.md`, `AGENTS.md`,
`REVIEW.md`, `SYSTEM-INTENT.md`, at any depth);
the developer says they reviewed and the agent appends `reviewed through
<40-hex sha> on <date>` to
`STATUS.md` in a commit that changes only that file (a line added by any
other commit acknowledges nothing), which covers exactly the first-parent
history of `{{BASE}}` up to that sha, never what merged while the line was in
review; a tag is a release step. The trade-off is speed against a review that can land after the
code. It is safe only while `{{BASE}}` is protected by a ruleset with a required
`gate` check, so the policy fails closed: when the required check is missing
from `{{BASE}}`'s rules, every merge waits for a human checkoff.
