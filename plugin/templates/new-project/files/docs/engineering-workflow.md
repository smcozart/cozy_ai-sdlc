# Engineering workflow

This repo runs the six-stage loop (Plan → Design → Build → Test → Deploy →
Maintain) of the `engineering-workflow` plugin, v{{PLUGIN_VERSION}}. The
loop and its contracts live in the plugin's `engineering-workflow` skill;
this file does not copy them. It holds only what is this repo's own: the
merge policy below (`docs/adr/*-adopt-engineering-workflow.md`).

## Deploy

A diff merges through a PR into `{{BASE}}`. Every PR runs the gate
(`.github/workflows/gate.yml` → `tests/validate.sh`) and owes the review in
`REVIEW.md`.

### Who merges

| Change | Who merges |
|---|---|
| A diff that touches `tests/validate.sh`, `.github/workflows/**` or `.githooks/**` — the files that check other files | A human, after a green gate and the review |
| A PR labelled `flagged-risk` | A human, after a named checkoff in the PR |
| Everything else | Merges on green; the review is owed after the merge and is not skipped |

- A commit that changes only `STATUS.md` (a board update) acknowledges the
  review of the work it reports.
- A tag is a release step, never part of a merge.

### Fail-closed

Merge on green holds only while `{{BASE}}` is protected: `gh api
repos/{owner}/{repo}/rules/branches/{{BASE}}` lists the `pull_request` rule and
the required status check `gate`. If it does not, every merge waits for a
human checkoff until it does.
