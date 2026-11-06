# Intent: the README says why the mattpocock-skills dependency carries no version

**Issue:** #163 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/README.md"]`

## Problem

The dependency has no version; projects drift (1.2.3 in one, 1.3.1 in another on one machine). A `version` range resolves only against `<plugin-name>--v<version>` tags, which `mattpocock/skills` does not publish, so a constraint today would make the install fail.

## Desired outcome

`plugin/README.md` says the dependency is unversioned, why it cannot be pinned today, and the command that brings a project up to date.

## Scope

`plugin/README.md` Dependencies section.

## Non-goals

A `version` field in `plugin.json` (breaks install until upstream tags); asking upstream to tag (the developer's call).

## Acceptance criteria

- The README paragraph cites the docs page and the tag mismatch.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0.

## System-intent alignment

A dependency's real state is written down, not discovered per machine.
