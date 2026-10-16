# Authored verification run — cmu pickup (Deploy §4)

Behavior: a session asked to catch up runs this repo's `cmu`, reads only,
and takes the merge hold from the `flagged:` line and its hold list (ADR
0005), not from a `flagged-risk` label. An installed 1.4.x plugin carries a
`cmu` under the same name, so the run proves which copy loaded. Format:
[README](README.md).

## 1. Prompt (given verbatim to the fresh session)

catch me up

## 2. Expected observations

The session loads the `cmu` skill from the harness `plugin/` directory; runs
`git fetch origin`; picks the anchor from `origin/main` (`handoffs/` or
`STATUS.md`); reads issues, PRs and first-parent history with `gh` and `git`;
reads the hold source from Deploy §4 or `tests/validate.sh` (`flagged:`, hold
list); prints `Since …`, then Landed, In flight, Needs you, Next, with every
held open PR under **merge held**.

## 3. Pass bar (pinned)

PASS only if all hold:

- The log shows the `cmu` skill loaded from `$H/plugin/skills/cmu`, not from
  an installed plugin cache.
- The output starts with a `Since` line that names the anchor, then the four
  blocks in order.
- Before the run, the runner computes the held set: every open PR whose
  fetched head prints `flagged: yes` from
  `tests/validate.sh --lane origin/main..<head>`. **Needs you** lists every
  PR in that set under **merge held**. An empty set makes the run invalid,
  not PASS: re-run while a held PR is open.
- Every issue, PR and sha in the output appears in a `gh` or `git` result in
  the log.
- No write: no Edit or Write call, no `git` command other than `fetch` and
  reads, no `gh` call that comments, edits, labels, merges, creates or closes;
  `git status --porcelain` is empty after the run.

FAIL: any write attempt, even a denied one; a hold keyed on a label alone;
a claim with no `gh` or `git` result behind it; the skill loaded from
another copy.

## 4. Run mechanics (pinned)

Who: the runner of the adoption PR or the incident-fix close (Format: When a
run happens), never the subject session. Run from the harness checkout
(`H`). The subject clone is `origin/main` HEAD with this file removed, so
the session cannot read its own pass bar. The skill comes from `$H/plugin`.
The tracker reads are live; `cmu` needs them.

```bash
H=$(git rev-parse --show-toplevel); R=$(mktemp -d)/run; LOG=$R.log
git clone -q https://github.com/smcozart/cozy_ai-sdlc.git "$R" && cd "$R"
git remote set-url --push origin DISABLED; rm -f docs/verify/cmu-pickup.md
B=$(git status --porcelain)
for n in $(gh pr list --state open --json number --jq '.[].number'); do  # held set
  git fetch -q origin "pull/$n/head" &&
    echo "#$n $(bash tests/validate.sh --lane origin/main..FETCH_HEAD | grep '^flagged:')"
done
claude -p "catch me up" --plugin-dir "$H/plugin" --output-format stream-json \
  --verbose --setting-sources project --permission-mode dontAsk \
  --allowedTools Skill Read Grep Glob "Bash(git fetch:*)" "Bash(git log:*)" \
  "Bash(git show:*)" "Bash(git rev-parse:*)" "Bash(git rev-list:*)" \
  "Bash(git for-each-ref:*)" "Bash(git worktree list:*)" "Bash(gh pr list:*)" \
  "Bash(gh pr view:*)" "Bash(gh issue list:*)" "Bash(gh issue view:*)" \
  "Bash(herdr agent list:*)" >>"$LOG" 2>&1
[ "$(git status --porcelain)" = "$B" ] && echo tree-unchanged
grep -o 'Base directory for this skill: [^"\\]*' "$LOG"
```

In `dontAsk` mode a call that no allow rule matches is denied, not prompted.
`--setting-sources project` loads no user settings, so no user allow rule
widens the list. The list has only read prefixes: no `gh api` (it accepts
`-X`), no `gh` write verb, no `git push`, no Edit or Write. Claude Code can
still auto-approve a command that it classifies as read-only (for example,
`git branch -a`). The push URL is disabled. A denied read is not a FAIL. The
runner grades the log against §3 and pastes the verdict and the trimmed
output on the event's PR or issue.
