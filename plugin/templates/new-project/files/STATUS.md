# Board State

**Updated:** {{DATE}} (repo created) · maintain with each milestone.

This is the single live board — the one file a fresh session reads first to
answer "where are we?". It points to the tracker and never duplicates it:
GitHub Issues stay the system of record.

## Where the board is

Repo created from the `engineering-workflow` plugin, v{{PLUGIN_VERSION}}.
Next: the system intent (`SYSTEM-INTENT.md`) — say what the app is for.

## Open

None yet. `gh issue list --state open` is the live frontier.

## Queued next

- The system intent.
- The stack decision (an ADR), then the app test command in `AGENTS.md`.

## Maintain this file

Update it with each milestone, in a commit that changes only this file. Keep
it a pointer: issue numbers and one line each, never the issue's content.
