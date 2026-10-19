# Handoffs

Session-to-session handoff documents, moved into the repo so they are
versioned and travel with clones. Each is a **context-under-the-floor of a
session** — the durable truth stays in the tracker, commits, specs, ADRs and
STANDARD.md; these capture the "you should pick up here" context that lives
in session chat.

> **For "where are we?", say "catch me up" (`cmu`)** — it reads the tracker
> and git; `../STATUS.md` is the review log. This folder is **archival**:
> point-in-time session context, not a live source. Nothing here is edited per session as the
> source of state.

| Doc | What it covers |
|---|---|
| `pickup-handoff.md` | Latest session pickup (archived) — re-enter the Harness; for current state say "catch me up" (`cmu`). |
| `deploy-to-maintain-handoff.md` | Handover from the Deploy stage → Maintain stage. |
| `test-to-deploy-stage-handoff.md` | Test → Deploy handover. |
| `build-stage-handoff.md` | Build-stage handover. |
| `design-stage-handoff.md` | Design-stage handover. |

## Rules

- A session archives its handoff here as a new `handoffs/<date-or-nick>.md`;
  it does **not** overwrite a "current" file to mirror live state; `cmu`
  derives live state from the tracker and git.
- Reference artifacts by path; do not duplicate spec/intent/ADR/issue text.
- Redact secrets/PII (none live in this repo's committed docs).
- **No live mirror:** `../STATUS.md` (root) is the review log, written only by
  the developer. This folder is archival session context, never a live mirror
  of state.