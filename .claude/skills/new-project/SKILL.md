---
name: new-project
description: >
  Put a folder under the engineering workflow: a brand-new repo from an empty
  folder (committed to main, created on GitHub and protected), or an existing
  repo through a PR on branch `adopt-engineering-workflow`. Scaffolds the files
  every plugin skill reads, runs the new gate, then hands off to
  `intent-conversation`. Use when the developer says "start a new project",
  "new app", "bootstrap this project" or "set up this repo for the workflow" —
  also in a repo that is already set up, where it answers in one line. A
  feature request ("a new app settings page") is not one of these.
---

# New project

One route. One question decides how the changes land: **does HEAD have
commits?** No: a brand-new repo — commit to `main`, create it on GitHub,
protect it. Yes: an existing repo — commit to branch
`adopt-engineering-workflow` and open a PR into the current branch; never
write to that branch directly, never touch its protection. The scaffold never
overwrites a file, so a re-run writes only what is missing.

**Never put the developer's words on a command line.** Owner, name and base
come from `gh` output, the origin URL, the folder name and git, checked by the
scaffold; visibility maps to a fixed flag.

**Dry run.** Skip Move 4 (every GitHub write) and say in one line which
moves you skipped; Move 5 still runs on the local commit. Read-only `gh`
lookups still run.

---

## Move 1 — Ground (read-only)

```bash
pwd -P; git rev-parse --show-toplevel 2>/dev/null
git rev-parse -q --verify HEAD; git branch --show-current; git for-each-ref --count=1
[ -z "$(git status --porcelain --untracked-files=normal 2>/dev/null)" ]; echo "clean: $?"
git remote get-url origin 2>/dev/null
git rev-parse -q --verify refs/heads/adopt-engineering-workflow
gh api user --jq .login; gh api user/orgs --jq '.[].login'
```

**Set up locally** means `AGENTS.md` holds `<!-- engineering-workflow:start -->`
or a `**Base branch:**` line, and `STATUS.md` exists.

Stop with one line, changing nothing, on the first that holds:

1. The current branch is `adopt-engineering-workflow`: "Switch back to your base branch first."
2. The toplevel exists and is not `pwd -P`: "This folder is inside the repo at `<toplevel>`."
3. Set up locally and `origin` exists: exactly this line, nothing else —
   > This repo is already set up for the workflow — say "catch me up" (`cmu`) to see where it stands.
4. In a repo and `clean` is not 0: "Commit, stash or remove untracked files first."
5. HEAD has no commits but `git for-each-ref` prints a ref: "This repo has branches but no commit on HEAD — not supported."
6. `gh api user` fails: "`gh` is offline or not logged in (`gh auth status`)."
7. HEAD has commits, `origin` exists, and the current branch is not the
   default of `<owner>/<name>` (`gh repo view <owner>/<name> --json defaultBranchRef --jq .defaultBranchRef.name`):
   "Switch to `<default>` first."
8. Branch `adopt-engineering-workflow` exists and
   `gh pr list -R <owner>/<name> --head adopt-engineering-workflow --state open --json url --jq '.[0].url'`
   prints a URL: "PR `<url>` is open — merge it, then tell me what the app is for."

**Base** = the current branch when HEAD has commits, else `main`.
**Owner/name**: with `origin`, parsed from its URL
(`github.com[:/]<owner>/<name>(.git)?`); else the `gh api user` login (or an
org, Move 2) and the folder name. The scaffold accepts only
`A-Z a-z 0-9 . _ -`; if the folder name has other characters, propose your
own — each of them replaced by `-` — in the one question; on a refusal, stop.
A name the developer types is never used.

Scaffold script: `<directory of this SKILL.md>/../../templates/new-project/scaffold.sh`;
in cozyharness's own `.claude/skills/` copy, `plugin/templates/new-project/scaffold.sh`
from the repo root. Neither exists: say so and stop.

## Move 2 — Ask (only without `origin`; at most one question)

Defaults: owner = the login, visibility = private. Ask only when
`gh api user/orgs` lists an org or the name needs your proposal:

> Create `<login>/<name>` as a private repo — or under `<org>`, or public?

## Move 3 — Scaffold and commit

Set up locally (and no `origin`, by Move 1): an earlier run already committed
the files; skip to Move 4.

Otherwise `<branch>` is `main` (no commits) or `adopt-engineering-workflow`:

```bash
# no commits:
[ -e .git ] || git init -b main
git symbolic-ref HEAD refs/heads/main
# commits (switch first, so the base checkout never holds the new files):
git switch adopt-engineering-workflow 2>/dev/null || git switch -c adopt-engineering-workflow

out=$(mktemp); echo "scaffold output: $out"
[ "$(git branch --show-current)" = <main|adopt-engineering-workflow> ] && bash <scaffold.sh> . --owner <owner> --name <name> --base <base> >"$out"; echo "scaffold exit $?"; cat "$out"
```

A non-zero exit: report the output and stop. Name every `skip:` of
`README.md`, `tests/validate.sh` or an ADR. When there are `wrote:` or
`appended:` lines, commit exactly those paths, and stop if `git add` fails:

```bash
git add -- $(sed -nE 's/^(wrote|appended): //p' <scaffold output>) && git commit -m "Adopt the engineering workflow"
```

With `origin` (an existing repo), read the protection first:
`gh api repos/<owner>/<name>/rules/branches/<base> --jq '[.[].type]'`. If it
lacks `required_status_checks`, add the fail-closed line (below) to
`docs/engineering-workflow.md` and the `docs/adr/*-adopt-engineering-workflow.md`
before the commit.

On `adopt-engineering-workflow`, end with `git switch <base>`.

Dry run: go to Move 5.

## Move 4 — GitHub

Every command against `<owner>/<name>`.

- **No `origin`:** `gh repo create <owner>/<name> --private --source . --push`
  (`--public` when chosen; it pushes `<base>` and makes it the default). A
  name clash fails: report it and stop. Then labels, and the ruleset with its
  read-back and required check — this run created the repo. If
  `adopt-engineering-workflow` holds a commit, push it and open the PR (next
  bullet, without the protection read).
- **`origin` exists:** `git push -u origin adopt-engineering-workflow`, then
  `gh pr create -R <owner>/<name> --base <base> --head adopt-engineering-workflow --title "Adopt the engineering workflow" --body "Adds the engineering workflow files (new-project)."`,
  then labels. No ruleset.

**Labels** (only the missing ones):

```bash
have=$(gh label list -R <owner>/<name> --limit 200 --json name --jq '.[].name')
for l in needs-triage needs-info ready-for-agent ready-for-human wontfix ticket flagged-risk; do
  grep -qx "$l" <<<"$have" || gh label create "$l" -R <owner>/<name>
done
```

**Ruleset** (a repo this run created), then the read-back:

```bash
gh api repos/<owner>/<name>/rulesets -X POST --input - <<'JSON'
{"name": "default", "target": "branch", "enforcement": "active",
 "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
 "rules": [{"type": "deletion"}, {"type": "non_fast_forward"},
   {"type": "pull_request", "parameters": {"required_approving_review_count": 0,
     "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false,
     "require_last_push_approval": false, "required_review_thread_resolution": false}}]}
JSON
gh api repos/<owner>/<name>/rules/branches/<base> --jq '[.[].type]'
```

Report a POST error; decide on the read-back alone. **Read-back `[]`** (a
private repo on a free plan): say so, add the fail-closed line to the end of
`docs/engineering-workflow.md` and `docs/adr/*-adopt-engineering-workflow.md`
on the branch that holds them (`main`, or `adopt-engineering-workflow` and
back), commit, push, and skip the required check:

`**Enforcement:** none (rules on <base> read back empty, <YYYY-MM-DD>) — pre-merge human checkoff until a ruleset is enforced.`

**Required check**, after the first `gate` run (`gh run list -R <owner>/<name> --limit 1`;
none after a few tries: say the policy stays fail-closed and stop):

```bash
gh run watch -R <owner>/<name> "$(gh run list -R <owner>/<name> --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
id=$(gh api repos/<owner>/<name>/rulesets --jq '.[] | select(.name == "default") | .id')
gh api repos/<owner>/<name>/rulesets/$id -X PUT --input - <<'JSON'
{"name": "default", "target": "branch", "enforcement": "active",
 "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
 "rules": [{"type": "deletion"}, {"type": "non_fast_forward"},
   {"type": "pull_request", "parameters": {"required_approving_review_count": 0,
     "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false,
     "require_last_push_approval": false, "required_review_thread_resolution": false}},
   {"type": "required_status_checks", "parameters": {"strict_required_status_checks_policy": false,
     "required_status_checks": [{"context": "gate"}]}}]}
JSON
gh api repos/<owner>/<name>/rules/branches/<base> --jq '[.[].type]'
```

The PUT resends the three rules. No `required_status_checks` in the
read-back: say the policy is fail-closed.

## Move 5 — Verify

The scaffolded gate on a clean clone of the branch that holds the files:

```bash
d=$(mktemp -d) && git clone -q -b <main|adopt-engineering-workflow> . "$d/c" && (cd "$d/c" && bash tests/validate.sh; bash tests/validate.sh --witness | tail -1)
```

Paste both. A red check in an existing repo (for example `adr-numbering` on
its own older ADRs) is reported, and posted on the PR
(`gh pr comment <url> --body-file <file with the output>`) — never fixed here.

## Move 6 — Hand off (one line, then stop)

- New repo: "Set up — tell me what the app is for."
- Existing repo: "PR `<url>` adds the workflow — merge it, then tell me what the app is for."
- Dry run: "Dry run done — nothing is on GitHub."
