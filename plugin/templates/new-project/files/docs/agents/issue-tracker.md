# Issue tracker: GitHub

Issues, tickets and their approvals live in this repo's GitHub Issues. Use
the `gh` CLI for every operation; it infers the repo from `git remote -v`.

## Conventions

- **Create**: `gh issue create --title "$(cat <title-file>)" --label needs-triage,ticket --body-file <body-file>`.
  Titles and bodies go through files, never typed on the command line.
- **Read**: `gh issue view <n> --comments`.
- **List**: `gh issue list --state open --json number,title,labels`.
- **Comment**: `gh issue comment <n> --body-file <file>`.
- **Labels**: `gh issue edit <n> --add-label <l>` / `--remove-label <l>`.
- **Close**: `gh issue close <n> --comment "<proof link>"`.

## Tickets and blocking edges

- A ticket is a GitHub sub-issue of its design issue; where sub-issues are
  not available, put `Part of #<n>` at the top of the ticket body.
- A blocking edge is written twice, always:
  1. GitHub's native dependency:
     `gh api -X POST repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by -F issue_id=<id>`,
     where `<id>` is the blocker's numeric database id
     (`gh api repos/{owner}/{repo}/issues/<m> --jq .id`), not its `#number`.
     `issue_dependencies_summary.blocked_by` counts the open blockers.
  2. A `Blocked by: #<m>` line at the top of the ticket body.
- A ticket is unblocked when every blocker is closed.

## The `ready-for-agent` contract

A ticket earns `ready-for-agent` when its blockers are closed, its
acceptance criteria are defined, and an approval comment is on the issue.
The comment comes first, then the label. No label, no work.

## Pull requests as a triage surface

**PRs as a request surface: no.**
