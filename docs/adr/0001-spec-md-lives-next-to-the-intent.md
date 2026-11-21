# spec.md lives next to the intent, linked by issue number

**Issue:** #3 · **Status:** accepted; Superseded by ADR 0008 (#181, 2026-11-17: no spec.md) · **Intent:** `intent/3-design-stage/intent.md`
(spec contract: the template, deleted by ADR 0008)

A spec could live in the GitHub issue body (where `/to-spec` publishes by
default) or in the repo. We chose the repo: `intent/<issue-number>-<slug>/spec.md`,
a sibling of the work-item intent, with the issue body linking to it by path
and the spec header linking back to the issue and intent. The issue body
stays a brief; the repo holds the durable artifact. This keeps the spec
diff-able, reviewable in PRs, and readable by any agent harness without API
access — the same reason intents live in the repo. The cost (two places to
open) is paid once per reader; the benefit (versioned, tool-portable design)
is paid back every session. Copying spec content into issues is forbidden:
reference by path only, so there is never a stale duplicate.
