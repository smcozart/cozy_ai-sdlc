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
list); prints `Since …`, then Landed, In flight, Needs you, Next.

## 3. Pass bar (pinned)

PASS only if all hold:

- The log shows the `cmu` skill loaded from `$H/plugin/skills/cmu`, not from
  an installed plugin cache.
- The output starts with a `Since` line that names the anchor, then the four
  blocks in order.
- **Needs you** keys the hold on `flagged:` or the hold list
  (`tests/validate.sh`, `.github/workflows/**`, `.githooks/**`), or says
  nothing is held.
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
(`H`). The subject clone is the golden tag `golden-main-2026-10-11`: main's
Deploy and `flagged:` line, no `cmu`, no copy of this file. The skill comes
from `$H/plugin`. The tracker reads are live; `cmu` needs them.

```bash
H=$(git rev-parse --show-toplevel); R=$(mktemp -d)/run; LOG=$R.log
git clone -q --branch golden-main-2026-10-11 \
  https://github.com/smcozart/cozyharness.git "$R" && cd "$R"
git remote set-url --push origin DISABLED
claude -p "catch me up" --plugin-dir "$H/plugin" --output-format stream-json \
  --verbose --permission-mode bypassPermissions \
  --disallowedTools Edit Write NotebookEdit "Bash(git push:*)" \
  "Bash(git commit:*)" "Bash(gh issue comment:*)" "Bash(gh issue edit:*)" \
  "Bash(gh pr comment:*)" "Bash(gh pr edit:*)" "Bash(gh pr merge:*)" >>"$LOG" 2>&1
git status --porcelain; grep -o 'Base directory for this skill: [^"\\]*' "$LOG"
```

The push URL is disabled and the write tools are denied, so the sandbox
cannot change the remote; the pass bar still fails a denied attempt. The
runner grades the log against §3 and pastes the verdict and the trimmed
output on the event's PR or issue.
