# Adopt the engineering workflow and its merge policy

**Issue:** none (repo creation, {{DATE}}) · **Status:** accepted

This repo runs the `engineering-workflow` plugin's six-stage loop
(v{{PLUGIN_VERSION}} at creation): GitHub Issues are the tracker, intents and
specs live in `intent/<n>-<slug>/`, decisions are ADRs here, and
`tests/validate.sh` is the gate. Merges follow one policy, written in
`docs/engineering-workflow.md` Deploy: a diff that touches
`tests/validate.sh`, `.github/workflows/**` or `.githooks/**` is held for a
human, because those files check every other file; everything else merges on
a green gate, with the review owed after the merge; a commit that changes
only `STATUS.md` acknowledges the review of the work it reports; a tag is a
release step. The trade-off is speed against a review that can land after the
code. It is safe only while `{{BASE}}` is protected by a ruleset with a required
`gate` check, so the policy fails closed: when the required check is missing
from `{{BASE}}`'s rules, every merge waits for a human checkoff.
