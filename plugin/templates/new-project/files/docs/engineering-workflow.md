# Engineering workflow

This repo runs the six-stage loop (Plan → Design → Build → Test → Deploy →
Maintain) of the `ai-sdlc` plugin, v{{PLUGIN_VERSION}}. The
loop and its contracts live in the plugin's skills (`intent-conversation`,
`dispatch`, `cmu`);
this file does not copy them. It holds only what is this repo's own: the
merge policy below (`docs/adr/*-adopt-engineering-workflow.md`).

## Deploy

A diff merges through a PR into `{{BASE}}`. Every PR runs the gate
(`.github/workflows/gate.yml` → `tests/validate.sh`) and owes the review in
`REVIEW.md`.

### Who merges

| Change | Who merges |
|---|---|
| `flagged: yes` from `tests/validate.sh --lane`: a diff that touches `tests/validate.sh`, `.github/workflows/**` or `.githooks/**` — the files that check other files | A human, after a green gate and a named checkoff in the PR; the PR carries the `flagged-risk` label |
| Everything else | Merges on green; a diff on a review path — skills (`skills/`), `docs/adr/`, `docs/engineering-workflow.md`, `AGENTS.md`, `REVIEW.md` and `SYSTEM-INTENT.md`, each at any depth — owes a review after the merge, and it is not skipped |

- The developer says in chat that they reviewed; the agent appends
  `reviewed through <40-hex sha> on <date>` to `STATUS.md` in a commit that
  changes only that file; a line added by any other commit acknowledges
  nothing. It covers exactly the first-parent history of `{{BASE}}` up to
  that sha, never what merged while the line was in review.
- A tag is a release step, never part of a merge.

### Fail-closed

Merge on green holds only while `{{BASE}}` is protected: `gh api
repos/{owner}/{repo}/rules/branches/{{BASE}}` lists the `pull_request` rule and
the required status check `gate`. If it does not, every merge waits for a
human checkoff until it does.
