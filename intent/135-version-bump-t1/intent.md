# Intent: a version-only plugin.json bump is lane T1

**Issue:** #135 · **Status:** approved · **Type:** system-change

**Touches:** `["tests/validate.sh", "docs/adr/0003-review-effort-follows-a-computed-lane.md"]`

From the harness review, Sean, 2026-10-18 (item 4).

## Problem

A release PR that bumps only `"version"` in `plugin/.claude-plugin/plugin.json` is lane T2 (#130), because the file is outside the light set. T2 asks for a full adversary pass for one version string.

## Desired outcome

In the root lane classifier (`lane_of` in `tests/validate.sh`), a range prints lane T1 when both are true:
- every changed file is in the light set, except `plugin/.claude-plugin/plugin.json`;
- that file's diff is exactly one removed line and one added line, and both match `^[[:space:]]*"version": "[0-9]+\.[0-9]+\.[0-9]+",?$`.

T1, not T0: a release still gets one bounded pass. The rule only lowers the computed T2 for this one shape. All other escalation rules come first: instruction files, deletes, binaries, symlinks, the file and line caps, and the hold list.

## Scope

- One rule in `lane_of`, plus its `lane_why` text: "version-only bump".
- ADR 0003 gets one sentence for this case, recorded as an "Amended" paragraph, in the ADR 0004 form.

## Non-goals

- The consumer template's classifier. Consumers have no `plugin.json` there.
- Any other light-set change.

## Acceptance criteria

- Witness rows (each must fail on `origin/main` before the change):
  - only the version line changed: T1;
  - the version line plus the `description` line: T2;
  - the version line plus a file outside the light set: T2;
  - the version line changed to a non-semver value: T2.
- `bash tests/validate.sh --witness` passes, and `template-gate-parity` still passes.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0 with `flagged: yes`. A named human merges.

## System-intent alignment

Review effort follows risk (ADR 0003): a version string gets one bounded pass, not a full adversary review.
