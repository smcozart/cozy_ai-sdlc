#!/usr/bin/env bash
# The Test gate: one command, one exit code, one line per check.
# Spec: intent/9-test-stage/spec.md (check tables are the requirement, verbatim).
#
#   tests/validate.sh [<range>]   run every check (sync-rule over <range>, else dirty tree, else HEAD~1..HEAD)
#   tests/validate.sh <range> <pr-body-file>  also run pr-adr-line on the PR body (CI passes it; skipped without it)
#   tests/validate.sh --list      print check names, one per line
#   tests/validate.sh --witness   run every fail-first witness (needs full history)
#   tests/validate.sh --lane [<range>]  classify the diff's review lane (T0/T1/T2) and merge hold from what git sees (ADR 0003)
#
# Requires: bash, git, grep/awk, python3 (stdlib). Offline. Never mutates the
# working tree — witness copies are `git worktree add` under $TMPDIR, trap-removed.
# Witnesses run against HEAD worktrees (committed state), not the dirty tree —
# deliberate: a witness proves the check's logic, the default run proves the tree.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE  # #45: a hook-exported GIT_DIR makes rev-parse return cwd (tests/), not the root
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 2

FO=plugin/skills/dispatch/SKILL.md
DOC=docs/engineering-workflow.md
CHECKS="sync-rule stage-parity intent-layout adr-numbering adr-refs skill-frontmatter skill-links template-gate-parity agents-commands dispatch-hold herdr-retire pr-adr-line"

fail=0; why=""
list_checks() { printf '%s\n' $CHECKS; }

# ---------- lane classifier (Deploy: review effort follows the lane; ADR 0003) ----------
# A classifier, not a check: it prints one `lane:` line and one `flagged:` line to paste beside the
# gate run. It is an ALLOW-list — only paths in LANE_LIGHT may take a reduced budget; everything else,
# including every path this repo has not grown yet, is T2. Renames are read as delete+add (--no-renames)
# so a move out of a protected path is the delete it is; every path is read NUL-separated (-z) so git never
# quotes it (#78: core.quotePath=off still quotes `"`, `\`, control chars) and LANE_HOLD sees the real path.
# Instruction files (LANE_NEVER, any case) are T2 wherever they sit; deletes, binaries and symlinks are T2
# (a symlink is never followed — its target may sit outside the repo). The agent still
# confirms "earns no ADR" and "not speculative", and may only ESCALATE the printed lane.
# Consumers extend LANE_LIGHT (safe by omission) and LANE_FLOOR_T1 (light files a session acts on).
# LANE_HOLD is the merge hold list (ADR 0005): the files that enforce the gate. `flagged: yes` = a human merges.
LANE_LIGHT='^(handoffs/|docs/training/|STATUS\.md$|LICENSE$)'
LANE_FLOOR_T1='^(STATUS\.md$|docs/training/|handoffs/pickup-handoff\.md$)'   # README.md anywhere is LANE_NEVER (T2), never a floor entry
LANE_NEVER='(^|/)(CLAUDE|AGENTS|GEMINI|COPILOT|README)\.md$|(^|/)\.(cursorrules|mcp\.json|gitmodules)$'
LANE_HOLD='^(tests/validate\.sh$|\.github/workflows/|\.githooks/|plugin/templates/new-project/files/tests/validate\.sh$|plugin/templates/new-project/files/\.github/workflows/|plugin/templates/new-project/scaffold\.sh$)'
LANE_MAX_FILES=2; LANE_MAX_LINES=60
lane_of() {  # lane_of <root> <range> -> sets lane (T0|T1|T2|none), lane_why and held; rc 2 when there is no lane
  local r=$1 range=$2 st files n never outside del ns lines bin untracked="" o links ver vd
  local -x LC_ALL=C   # paths are bytes: a UTF-8 locale makes tr/cut abort on an invalid byte and drop the hold (#78)
  held=""
  # -z output, one record per line: NUL ends the record, a newline inside a path becomes a tab (still a control char)
  st=$(git -C "$r" diff -z --no-renames --name-status "$range" 2>/dev/null | tr '\n\0' '\t\n' | paste - -) || { lane=none; lane_why="git diff $range failed — fix the range"; return 2; }
  # the dirty tree includes untracked files; `git diff HEAD` does not list them, so a new file would otherwise vanish from the lane
  [ "$range" != HEAD ] || untracked=$(git -C "$r" ls-files -z --others --exclude-standard | tr '\n\0' '\t\n')
  [ -n "$st$untracked" ] || { lane=none; lane_why="empty range — fix the range"; return 2; }
  files=$({ [ -z "$st" ] || cut -f2- <<<"$st"; [ -z "$untracked" ] || printf '%s\n' "$untracked"; }); n=$(grep -c . <<<"$files")
  held=$(grep -E "$LANE_HOLD" <<<"$files" | tr '\n' ' ')
  del=$(awk -F'\t' '$1 ~ /^D/ {print $2}' <<<"$st" | tr '\n' ' ')
  never=$(grep -iE "$LANE_NEVER" <<<"$files" | tr '\n' ' ')
  links=$(git -C "$r" diff -z --no-renames --raw "$range" | tr '\n\0' '\t\n' | paste - - | awk -F'\t' '$1 ~ / 120000 |^:120000 / {print $2}' | tr '\n' ' ')
  # a path git would quote (`"`, `\`, control char) or that is not UTF-8 is never light: the real name must not lower the lane (#78, escalate only)
  # #135: a version-only bump of the plugin manifest is not "outside"; it floors at T1 below. Numstat 1 1 in one hunk, and both
  # lines are a semver "version" line that is the same once the semver is masked (uniq -c = 2): same place, comma and indent
  ver=plugin/.claude-plugin/plugin.json; vd=$(git -C "$r" diff --no-renames -U0 "$range" -- "$ver")
  { grep -qxF "$ver" <<<"$files" && [ "$(git -C "$r" diff --no-renames --numstat "$range" -- "$ver" | cut -f1-2)" = $'1\t1' ] && [ "$(grep -c '^@@' <<<"$vd")" = 1 ] \
    && [ "$(grep -E '^[-+][[:space:]]*"version": "[0-9]+\.[0-9]+\.[0-9]+",?$' <<<"$vd" | sed -E 's/^[-+]//; s/[0-9]+\.[0-9]+\.[0-9]+/V/' | uniq -c | awk '{print $1}')" = 2 ]; } || ver=""
  outside=$({ grep -vE "$LANE_LIGHT" <<<"$files" | if [ -n "$ver" ]; then grep -vxF "$ver"; else cat; fi; grep -E "$LANE_LIGHT" <<<"$files" | grep -E '["\\[:cntrl:]]'; iconv -f UTF-8 -t UTF-8 <<<"$files" >/dev/null 2>&1 || echo '(a non-UTF-8 path)'; } | tr '\n' ' ')
  ns=$(git -C "$r" diff -z --no-renames --numstat "$range" | tr '\n\0' '\t\n' | awk -F'\t' '$1=="-"||$2=="-"{b=1} {a+=$1; d+=$2} END{print a+d+0, b+0}')
  lines=${ns%% *}; bin=${ns##* }
  while IFS= read -r -d '' o; do   # untracked, real names: count lines ourselves, NUL byte = binary; never follow a symlink
    if [ -L "$r/$o" ]; then links="$links$o "
    elif [ ! -f "$r/$o" ] || [ ! -r "$r/$o" ]; then bin=1   # not a readable regular file (an untracked nested repo lists as dir/): never counted, T2
    elif [ "$(head -c 8000 "$r/$o" | tr -d '\000' | wc -c)" -ne "$(head -c 8000 "$r/$o" | wc -c)" ]; then bin=1; else lines=$((lines + $(wc -l <"$r/$o"))); fi
  done < <([ "$range" != HEAD ] || git -C "$r" ls-files -z --others --exclude-standard)
  if   [ -n "$never" ];                       then lane=T2; lane_why="instruction file: ${never% }"
  elif [ -n "$outside" ];                     then lane=T2; lane_why="outside the light set: ${outside% }"
  elif [ -n "$links" ];                       then lane=T2; lane_why="symlink (not followed): ${links% }"
  elif [ -n "$del" ];                         then lane=T2; lane_why="deletes: ${del% }"
  elif [ "$bin" = 1 ];                        then lane=T2; lane_why="binary file in range"
  elif [ "$n" -gt "$LANE_MAX_FILES" ];        then lane=T2; lane_why="$n files (>$LANE_MAX_FILES)"
  elif [ "$lines" -gt "$LANE_MAX_LINES" ];    then lane=T2; lane_why="$lines changed lines (>$LANE_MAX_LINES)"
  elif grep -qE "$LANE_FLOOR_T1" <<<"$files"; then lane=T1; lane_why="floors at T1 ($(grep -E "$LANE_FLOOR_T1" <<<"$files" | tr '\n' ' ' | sed 's/ $//')): a session acts on it"
  elif [ -n "$ver" ];                         then lane=T1; lane_why="version-only bump"
  elif ! grep -qvE '\.md$' <<<"$files";       then lane=T0; lane_why="$n file(s), docs-only, $lines lines, all in the light set"
  else                                           lane=T1; lane_why="$n file(s), $lines changed lines, all in the light set"
  fi
}
lane_run() {  # lane_run [<range>] -> prints the lane and flagged lines with resolved shas; exit 0 on a lane, 2 on none
  local range=${1:-} a b m hit="" base="" shown partial="" t bl refs="origin/main main"
  # the base branch: LANE_TARGET overrides AGENTS.md's **Base branch:** line; neither set = main, as before (#47)
  bl=$(grep -m1 '^\*\*Base branch' AGENTS.md 2>/dev/null | tr -d '\r')
  t=${LANE_TARGET:-$(sed -nE 's/^\*\*Base branch:\*\*[[:space:]]*`?([^`[:space:]]+)`?.*/\1/p' <<<"$bl")}
  [ -z "$t" ] || refs="origin/$t $t"
  # dirty = tracked changes OR untracked files; a new file alone must not fall through to HEAD~1..HEAD
  if [ -z "$range" ]; then if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then range=HEAD; else range=HEAD~1..HEAD; fi; fi
  lane_of . "$range"; lane_why=${lane_why//[[:cntrl:]]/?}; held=${held//[[:cntrl:]]/?}   # raw names: no control char reaches the terminal
  if [ "$range" = HEAD ]; then shown="dirty tree vs $(git rev-parse --short HEAD)"
  elif [[ $range == *..* ]]; then
    a=$(git rev-parse --short "${range%%..*}" 2>/dev/null); b=$(git rev-parse --short "${range##*..}" 2>/dev/null); shown="$a..$b"
    for m in $refs; do git rev-parse -q --verify "$m^{commit}" >/dev/null 2>&1 && { hit=$m; base=$(git merge-base "$m" "${range##*..}" 2>/dev/null); break; }; done
    # a partial range hides files: the close needs the ticket's full range, i.e. merge-base(base, tip)..tip
    # a configured base fails closed: unreadable line, no ref, or no common history all print PARTIAL
    if [ -z "$t" ] && [ -n "$bl" ]; then partial=" — PARTIAL RANGE (base branch line in AGENTS.md unreadable); not valid for a close"
    elif [ -n "$base" ] && [ "$(git rev-parse "${range##*..}")" != "$(git rev-parse "$m")" ] \
       && [ "$(git rev-parse "${range%%..*}" 2>/dev/null)" != "$base" ]; then partial=" — PARTIAL RANGE (base is not the merge-base with $m); not valid for a close"
    elif [ -n "$t" ] && [ -z "$hit" ]; then partial=" — PARTIAL RANGE (base branch $t not found); not valid for a close"
    elif [ -n "$t" ] && [ -z "$base" ]; then partial=" — PARTIAL RANGE (no common history with $hit); not valid for a close"; fi
  else shown=$range; fi
  case $lane in
    none) echo "lane: none — $lane_why ($shown)"; return 2;;
    T0)   echo "lane: T0 trivial — $lane_why ($shown)$partial";;
    T1)   echo "lane: T1 light — $lane_why ($shown)$partial";;
    *)    echo "lane: T2 heavy — $lane_why ($shown)$partial";;
  esac
  if [ -n "$held" ]; then echo "flagged: yes — merge hold, a human merges: ${held% }"; else echo "flagged: no"; fi
  [ "$lane" = T2 ] || echo "confirm at close (fill in): no-ADR=<y/n> not-speculative=<y/n> — any n means T2. Escalate only."
  return 0
}

# ---------- static half: check_<name> <root> (sync-rule: <range>) ----------
check_sync_rule() {  # $1 = git range
  local files
  files=$(git diff --name-only "$1" 2>/dev/null) || { why="git diff $1 failed (bad range or shallow clone; git fetch --unshallow)"; return 1; }
  grep -qxF "$DOC" <<<"$files" || return 0
  grep -qxF README.md <<<"$files" || { why="$1 touches $DOC without README.md"; return 1; }
}

check_stage_parity() {
  local r=$1 d m
  for f in "$DOC" README.md; do [ -f "$r/$f" ] || { why="$f missing"; return 1; }; done
  d=$(grep -cE '^## (Plan|Design|Build|Test|Deploy|Maintain)\b' "$r/$DOC")
  m=$(grep -cE '^(Plan|Design|Build|Test|Deploy|Maintain) (─)+►' "$r/README.md")
  [ "$d$m" = 66 ] || { why="expected 6 stage headings each; found doc=$d README=$m"; return 1; }
  d=$(grep -oE '^## (Plan|Design|Build|Test|Deploy|Maintain)\b' "$r/$DOC" | grep -oE '(Plan|Design|Build|Test|Deploy|Maintain)' | sort -u | wc -l | tr -d " ")
  m=$(grep -oE '^(Plan|Design|Build|Test|Deploy|Maintain) (─)+►' "$r/README.md" | grep -oE '(Plan|Design|Build|Test|Deploy|Maintain)' | sort -u | wc -l | tr -d " ")
  [ "$d$m" = 66 ] || { why="expected 6 distinct stage names each; found doc=$d README=$m"; return 1; }
}

check_intent_layout() {
  local r=$1 d n slug got
  for d in "$r"/intent/*/; do
    d=${d%/}; slug=${d##*/}
    [[ $slug =~ ^[0-9]+-[a-z0-9-]+$ ]] || { why="intent/$slug: bad dir name"; return 1; }
    n=${slug%%-*}
    [ -f "$d/intent.md" ] || { why="intent/$slug/intent.md missing"; return 1; }
    got=$(grep -oE '^\*\*Issue:\*\* #[0-9]+' "$d/intent.md" | head -1 | grep -oE '[0-9]+$')
    [ "$got" = "$n" ] || { why="intent/$slug/intent.md: expected **Issue:** #$n, found #${got:-none}"; return 1; }
    [ -f "$d/spec.md" ] || continue
    got=$(grep -oE '^\*\*Issue:\*\* #[0-9]+' "$d/spec.md" | head -1 | grep -oE '[0-9]+$')
    [ "$got" = "$n" ] || { why="intent/$slug/spec.md: expected **Issue:** #$n, found #${got:-none}"; return 1; }
    grep -qF "**Intent:** \`intent/$slug/intent.md\`" "$d/spec.md" \
      || { why="intent/$slug/spec.md: **Intent:** does not point at intent/$slug/intent.md"; return 1; }
  done
}

check_adr_numbering() {
  local r=$1 f b i=0 want
  [ -d "$r/docs/adr" ] && ls "$r"/docs/adr/*.md >/dev/null 2>&1 || { why="docs/adr has no *.md"; return 1; }
  for f in "$r"/docs/adr/*.md; do
    b=${f##*/}; i=$((i+1)); want=$(printf '%04d' "$i")
    [[ $b =~ ^[0-9]{4}-[a-z0-9-]+\.md$ ]] || { why="docs/adr/$b: bad name"; return 1; }
    [ "${b:0:4}" = "$want" ] || { why="docs/adr/$b: expected $want (contiguous 0001..N)"; return 1; }
    grep -q '^\*\*Issue:\*\*' "$f" || { why="docs/adr/$b: no **Issue:** header"; return 1; }
  done
}

check_adr_refs() {
  local r=$1 f bad="" line n
  for f in AGENTS.md CONTRIBUTING.md README.md CONTEXT.md "$DOC"; do [ -f "$r/$f" ] || { why="$f missing"; return 1; }; done
  while IFS= read -r line; do
    n=$(grep -oE '[0-9]{4}' <<<"${line##*:}")
    ls "$r"/docs/adr/"$n"-*.md >/dev/null 2>&1 || bad="$bad ${line%:*}(${line##*:})"
  done < <(cd "$r" && grep -rnoiE 'adr[ -]?[0-9]{4}|docs/adr/[0-9]{4}' AGENTS.md CONTRIBUTING.md README.md CONTEXT.md "$DOC" docs/adr intent plugin)
  [ -z "$bad" ] || { why="no docs/adr/NNNN-*.md for:$bad"; return 1; }
}

check_skill_frontmatter() {
  local r=$1 f d files
  files=$(git -C "$r" ls-files '*/skills/*/SKILL.md')
  [ -n "$files" ] || { why="git ls-files matched no */skills/*/SKILL.md"; return 1; }
  while IFS= read -r f; do
    d=$(basename "$(dirname "$f")")
    awk -v d="$d" 'NR==1&&$0!="---"{bad=1} NR>1&&!e&&$0=="---"{e=1} NR>1&&!e&&$0=="name: "d{n=1} NR>1&&!e&&/^description: .+/{de=1} END{exit !(e&&n&&de&&!bad)}' "$r/$f" \
      || { why="$f: expected --- / name: $d / description: … / --- frontmatter"; return 1; }
  done <<<"$files"
}

SKILL_LINKS=".claude/skills/cmu .claude/skills/dispatch .claude/skills/intent-conversation .claude/skills/new-project"
check_skill_links() {  # each host copy is a link into plugin/skills/; the index mode alone is not enough — core.symlinks=false still reports 120000
  local r=$1 l want
  for l in $SKILL_LINKS; do
    want=../../plugin/skills/${l##*/}
    [ -L "$r/$l" ] || { why="$l is not a symlink — enable symlinks (\`git config core.symlinks true\`, Windows Developer Mode) and re-checkout"; return 1; }
    [ "$(readlink "$r/$l")" = "$want" ] || { why="$l -> $(readlink "$r/$l"), expected $want"; return 1; }
    [ -f "$r/$l/SKILL.md" ] || { why="$l -> $want has no SKILL.md (dangling link)"; return 1; }
  done
}

check_template_gate_parity() {  # the scaffolded gate must hold and size like this one: same staged diff, same lane:/flagged: lines
  local r=$1 t=$1/plugin/templates/new-project/files d f p a b rc=0
  cmp -s "$r/.pi/agents/adversary.md" "$t/.pi/agents/adversary.md" \
    || { why=".pi/agents/adversary.md and its template copy differ (must be byte-identical)"; return 1; }
  d=$(mktemp -d "${TMPDIR:-/tmp}/parity.XXXXXX"); mkdir -p "$d/tests"   # a temp repo, never a worktree
  cp "$r/tests/validate.sh" "$d/tests/validate.sh" && cp "$t/tests/validate.sh" "$d/tests/template.sh" && git -C "$d" init -q && git -C "$d" add -A \
    && git -C "$d" -c user.name=parity -c user.email=parity@localhost -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm base \
    || { why="cannot build the temp repo in $d"; rm -rf "$d"; return 1; }
  for f in 'tests/validate.sh .githooks/x .github/workflows/a"b.yml' handoffs/x.md; do   # every shared hold alternative + a name git quotes, then a light path
    for p in $f; do mkdir -p "$d/${p%/*}"; printf '# x\n' >>"$d/$p"; git -C "$d" add "$p"; done
    a=$(bash "$d/tests/validate.sh" --lane | grep -E '^(lane|flagged):'); b=$(bash "$d/tests/template.sh" --lane | grep -E '^(lane|flagged):')
    [[ $a == *flagged:* ]] && [ "$a" = "$b" ] || { why="$f: main [${a//$'\n'/ | }] vs template [${b//$'\n'/ | }]"; rc=1; break; }
    git -C "$d" reset -q --hard
  done
  rm -rf "$d"; return $rc
}

check_agents_commands() {
  local r=$1 have want
  [ -f "$r/AGENTS.md" ] || { why="AGENTS.md missing"; return 1; }
  have=$(awk '/^## Commands/{c=1;next} /^## /{c=0} c' "$r/AGENTS.md" | grep -oE '`[a-z0-9-]+`' | tr -d '`' | sort -u)
  want=$(list_checks | sort -u)
  [ "$have" = "$want" ] || { why="AGENTS.md ## Commands names != --list; missing:[$(comm -13 <(echo "$have") <(echo "$want") | tr '\n' ' ')] extra:[$(comm -23 <(echo "$have") <(echo "$want") | tr '\n' ' ')]"; return 1; }
}

# dispatch-hold  plugin dispatch skill (#42, ADR 0005): the merge step ties to `flagged: no`; the old fail-open line is gone  witness: mutation rows
check_dispatch_hold() {  # whitespace-joined, so a reflow neither hides the old line nor breaks the tie
  local t; t=$(tr -s '[:space:]' ' ' <"$1")
  grep -qF "and the gate run's \`flagged:\` line says \`flagged: no\`" <<<"$t" && ! grep -qF 'plus this one QC check merges' <<<"$t" \
    || { why="$1: expected the merge tied by 'and the gate run's \`flagged:\` line says \`flagged: no\`' and no 'plus this one QC check merges'"; return 1; }
}

# herdr-retire  dispatch's herdr row (#97, #146): retire removes the worker's clone only behind the squash-safe guard  witness: mutation rows
check_herdr_retire() {  # whitespace-joined, like dispatch-hold
  local t; t=$(tr -s '[:space:]' ' ' <"$1")
  grep -qF "then remove the worker's clone (\`rm -rf <clone>\`) only if \`git -C <clone> status --porcelain\` is empty, \`git -C <clone> stash list\` is empty, \`git -C <clone> log --oneline --branches --not --remotes HEAD\` is empty, \`gh pr view <pr> --json state,headRefOid\` says \`MERGED\` and \`git -C <clone> rev-parse HEAD\` equals its \`headRefOid\` — what QC checked and was merged is all the clone holds. Otherwise keep it and name it, with the reason, on the roster." <<<"$t" \
    || { why="$1: expected the clone removal behind status clean + no stash + no unpushed branch commit + MERGED + HEAD == headRefOid, else keep it"; return 1; }
}

# pr-adr-line  PR body file (ADR 0005: every PR body carries an ADR: line; presence only)  witness: three mutation rows
check_pr_adr_line() {  # a fenced line is quoted text, not the PR's own ADR line
  awk '/^[[:space:]]*(```|~~~)/{f=!f; next} !f' "$1" | grep -qE '^ADR:[[:space:]]*[^[:space:]]' || { why="$1: no 'ADR:' line (write 'ADR: none' when the PR records no decision)"; return 1; }
}

# ---------- runner ----------
verdict() {  # verdict <name> <arg> -> sets v=ok|FAIL and why (no subshell: why must survive)
  local name=$1; shift; why=""; v=FAIL
  if [ -f "$1" ] || [ -d "$1" ] || [ "$name" = sync-rule ]; then
    "check_${name//-/_}" "$@" && v=ok
  else why="$1: file missing"; fi
}
fail_count=0; ran_ok=0  # ran_* counts what actually ran (F2: the summary must not derive from --list)
run() {
  verdict "$@"
  case $v in ok) echo "ok: $1"; ran_ok=$((ran_ok+1)) ;; *) echo "FAIL: $1 — $why"; fail=1; fail_count=$((fail_count+1)) ;; esac
}

default_run() {
  local range=${1:-} body=${2:-}
  if [ -z "$range" ]; then
    if ! git diff --quiet HEAD 2>/dev/null; then range=HEAD; else range=HEAD~1..HEAD; fi
  fi
  run sync-rule "$range"
  for c in stage-parity intent-layout adr-numbering adr-refs skill-frontmatter skill-links template-gate-parity agents-commands; do run "$c" .; done
  run dispatch-hold plugin/skills/dispatch/SKILL.md
  run herdr-retire "$FO"
  if [ -n "$body" ]; then run pr-adr-line "$body"; else echo "skipped: pr-adr-line — no PR body file given (CI passes one)"; fi
  echo "$ran_ok ok, $fail_count failed (range: $range)"
  lane_run "$range" || true   # trailer, not a check: same range as the gate so one paste carries both (ADR 0003)
}

# ---------- witness mode ----------
BASE=  # every worktree and temp file lives under one mktemp dir; trap removes it all
cleanup() { for w in "$BASE"/wt-*; do [ -d "$w" ] && git worktree remove --force "$w" >/dev/null 2>&1; done; rm -rf "$BASE"; git worktree prune; }
worktree() {  # worktree <sha> -> sets W (no subshell: a failed add must abort, never a vacuous FAIL row)
  W=$BASE/wt-$1
  git worktree add --detach --quiet "$W" "$1" >/dev/null 2>&1 || { echo "!! cannot check out $1 (git fetch --unshallow?)" >&2; exit 2; }
}
wfail=0; wn=0
expect() {  # expect <ok|FAIL> <label> <check> <arg>
  local want=$1 label=$2 name=$3 arg=$4; wn=$((wn+1))
  verdict "$name" "$arg"
  if [ "$v" = "$want" ]; then echo "witness ok: $name @$label expected $want${why:+ ($why)}"
  else echo "witness FAIL: $name @$label expected $want, got $v${why:+ — $why}"; wfail=1; fi
}
have_sha() { git cat-file -e "$1^{commit}" 2>/dev/null || { echo "witness FAIL: sha $1 not in history (git fetch --unshallow)"; wfail=1; return 1; }; }
showfile() {  # showfile <sha> <path> -> sets T (no subshell: a failed git show must abort, never a vacuous FAIL)
  T=$BASE/$1-${2##*/}
  git show "$1:$2" >"$T" 2>/dev/null || { echo "!! git show $1:$2 failed"; exit 2; }
}
reset_wt() { git -C "$1" checkout --quiet -- . && git -C "$1" clean -fdq; }

witness_run() {
  [ "$(git rev-parse --is-shallow-repository)" = false ] || { echo "!! shallow clone: run 'git fetch --unshallow' first"; exit 2; }
  BASE=$(mktemp -d "${TMPDIR:-/tmp}/validate.XXXXXX"); trap cleanup EXIT
  for s in a6519a9 571afe4 1b41a31; do have_sha "$s" || exit 2; done

  # sha witnesses — static
  expect FAIL a6519a9 sync-rule 'a6519a9~1..a6519a9'
  expect ok   571afe4 sync-rule '571afe4~1..571afe4'
  worktree 1b41a31; local w=$W
  expect FAIL 1b41a31 stage-parity "$w"
  expect FAIL 1b41a31 adr-refs "$w"

  # mutation witnesses — one-line mutations on a worktree copy of HEAD, reset between rows
  worktree HEAD; local m=$W
  expect ok baseline stage-parity "$m"
  # #45: the whole gate under a hook-exported GIT_DIR in a linked worktree (end-to-end, not one check)
  gitdir_row() {  # gitdir_row <ok|FAIL> <label>
    local got=FAIL; wn=$((wn+1))
    (cd "$m" && GIT_DIR=$(git rev-parse --git-dir) bash tests/validate.sh HEAD..HEAD >/dev/null 2>&1) && got=ok
    if [ "$got" = "$1" ]; then echo "witness ok: gate @$2 expected $1"
    else echo "witness FAIL: gate @$2 expected $1, got $got"; wfail=1; fi
  }
  gitdir_row ok GIT_DIR-linked-worktree
  grep -v '^unset GIT_DIR GIT_WORK_TREE' "$m/tests/validate.sh" > "$m/t" && mv "$m/t" "$m/tests/validate.sh"
  gitdir_row FAIL 'mutation(-unset GIT_DIR)'; reset_wt "$m"
  # F2: the summary must count what ran, not what --list says — a skipped or dropped check must not inflate it
  sum_row() {  # sum_row <ok|FAIL> <label> — summary ok-count must equal printed ok: lines
    wn=$((wn+1)); local out sum lines
    out=$(cd "$m" && bash tests/validate.sh HEAD..HEAD 2>/dev/null)
    lines=$(grep -c '^ok: ' <<<"$out"); sum=$(grep -oE '^[0-9]+ ok, [0-9]+ failed' <<<"$out" | head -1); sum=${sum%% *}
    if { [ "$1" = ok ] && [ "$sum" = "$lines" ]; } || { [ "$1" = FAIL ] && [ "$sum" != "$lines" ]; }
    then echo "witness ok: summary @$2 expected $1 (summary=$sum, ok-lines=$lines)"
    else echo "witness FAIL: summary @$2 expected $1, got summary=$sum vs ok-lines=$lines"; wfail=1; fi
  }
  sum_row ok 'baseline — summary counts what ran'
  sed -i.bak 's/echo "\$ran_ok ok, \$fail_count failed/echo "99 ok, \$fail_count failed/' "$m/tests/validate.sh" && rm -f "$m/tests/validate.sh.bak"
  sum_row FAIL 'mutation(summary hardcoded — the F2 bug shape)'; reset_wt "$m"
  (cd "$m" && python3 -c "p='intent/9-test-stage/intent.md';s=open(p).read().replace('#9','#8');open(p,'w').write(s)")
  expect FAIL mutation intent-layout "$m"; reset_wt "$m"
  : >"$m/docs/adr/0009-x.md"
  expect FAIL mutation adr-numbering "$m"; reset_wt "$m"
  (cd "$m" && grep -v '^name:' $FO > t && mv t $FO)
  expect FAIL mutation skill-frontmatter "$m"; reset_wt "$m"
  # skill-links: a good tree, then the three ways a link breaks; the first is a real core.symlinks=false checkout (Windows)
  expect ok baseline skill-links "$m"
  rm "$m/.claude/skills/cmu"; git -C "$m" -c core.symlinks=false checkout -- .claude/skills/cmu
  expect FAIL 'mutation(link checked out as a text file)' skill-links "$m"; reset_wt "$m"
  [[ $why == *'enable symlinks'* ]] || { echo "witness FAIL: skill-links @mutation(link checked out as a text file) expected the message to name the fix (enable symlinks), got: $why"; wfail=1; }
  ln -sfn ../../plugin/skills/dispatch "$m/.claude/skills/cmu"
  expect FAIL 'mutation(link to the wrong skill)' skill-links "$m"; reset_wt "$m"
  rm -rf "$m/plugin/skills/cmu"
  expect FAIL 'mutation(dangling link)' skill-links "$m"; reset_wt "$m"
  # template-gate-parity: the baseline row keeps the mutation rows from passing on a missing check
  expect ok baseline template-gate-parity "$m"
  sed -i.bak 's/^LANE_HOLD=.*/LANE_HOLD=nothing-held/' "$m/plugin/templates/new-project/files/tests/validate.sh"
  expect FAIL "mutation(template LANE_HOLD)" template-gate-parity "$m"; reset_wt "$m"
  sed -i.bak "s|^LANE_HOLD=.*|LANE_HOLD='^(.github/workflows/)'|" "$m/plugin/templates/new-project/files/tests/validate.sh"
  expect FAIL "mutation(template LANE_HOLD partial — workflows only)" template-gate-parity "$m"; reset_wt "$m"
  echo x >> "$m/plugin/templates/new-project/files/.pi/agents/adversary.md"
  expect FAIL 'mutation(template adversary copy)' template-gate-parity "$m"; reset_wt "$m"
  grep -v '^## Maintain' "$m/$DOC" > "$m/t" && mv "$m/t" "$m/$DOC"
  expect FAIL 'mutation(-## Maintain)' stage-parity "$m"; reset_wt "$m"
  grep -v '^Maintain ' "$m/README.md" > "$m/t" && mv "$m/t" "$m/README.md"
  expect FAIL 'mutation(-Maintain README)' stage-parity "$m"; reset_wt "$m"
  sed -i.bak 's/^## Maintain/## Test/' "$m/$DOC"
  expect FAIL 'mutation(## Maintain→## Test)' stage-parity "$m"; reset_wt "$m"
  sed -i.bak 's/^Maintain ─►/Test ──►/' "$m/README.md"
  expect FAIL 'mutation(Maintain─►→Test README)' stage-parity "$m"; reset_wt "$m"
  # agents-commands: rewrite the ## Commands block with every --list name (control: ok), then all but one (FAIL)
  commands_block() { awk '/^## Commands/{c=1;next} /^## /{c=0} !c' "$m/AGENTS.md"; echo; echo '## Commands'; echo; list_checks | sed "$1" | sed 's/.*/`&`/' | tr '\n' ' '; echo; }
  commands_block '' > "$m/AGENTS.tmp" && mv "$m/AGENTS.tmp" "$m/AGENTS.md"
  expect ok 'mutation(full block)' agents-commands "$m"; reset_wt "$m"
  commands_block 1d > "$m/AGENTS.tmp" && mv "$m/AGENTS.tmp" "$m/AGENTS.md"
  expect FAIL 'mutation(one name deleted)' agents-commands "$m"; reset_wt "$m"

  showfile HEAD plugin/skills/dispatch/SKILL.md;                                      expect ok baseline dispatch-hold "$T"
  sed -i.bak 's/flagged: no/flagged: maybe/' "$T";                                    expect FAIL 'mutation(-flagged: no tie)' dispatch-hold "$T"
  showfile HEAD plugin/skills/dispatch/SKILL.md; echo 'Green `validate` plus this one QC check merges — no' >>"$T"; expect FAIL 'mutation(+f467444 merge line)' dispatch-hold "$T"
  showfile HEAD plugin/skills/dispatch/SKILL.md; printf 'Green `validate` plus this one\nQC check merges — no\n' >>"$T"; expect FAIL 'mutation(+f467444 line reflowed)' dispatch-hold "$T"
  showfile HEAD plugin/skills/dispatch/SKILL.md; sed -i.bak "s/passed, and the gate run's/passed, or the gate run's/" "$T"; expect FAIL 'mutation(and→or tie)' dispatch-hold "$T"
  showfile HEAD $FO;                                                                  expect ok baseline herdr-retire "$T"
  sed -i.bak "s/then remove the worker's clone (\`rm -rf <clone>\`) //" "$T";              expect FAIL 'mutation(-clone removal)' herdr-retire "$T"
  showfile HEAD $FO; sed -i.bak 's/`git -C <clone> rev-parse HEAD` equals its `headRefOid` //' "$T"; expect FAIL 'mutation(-headRefOid comparison)' herdr-retire "$T"
  showfile HEAD $FO; sed -i.bak 's/`git -C <clone> stash list` is empty, //' "$T";            expect FAIL 'mutation(-stash list condition)' herdr-retire "$T"
  showfile HEAD $FO; sed -i.bak 's/Otherwise keep it and name it/Otherwise remove it anyway and name it/' "$T"; expect FAIL 'mutation(fallback→remove it anyway)' herdr-retire "$T"
  printf 'Summary\n\nNo decision line.\n' >"$BASE/body";                              expect FAIL 'mutation(PR body, no ADR: line)' pr-adr-line "$BASE/body"
  printf 'Summary\n\nADR: none\n' >"$BASE/body";                                      expect ok 'PR body, ADR: none' pr-adr-line "$BASE/body"
  printf 'Summary\n\n```\nADR: none\n```\n' >"$BASE/body";                            expect FAIL 'mutation(PR body, ADR: line only fenced)' pr-adr-line "$BASE/body"

  # lane classifier (ADR 0003) — one row per decision branch plus every known evasion;
  # a wrong lane is a wrong review budget. Historic ranges first, then mutations on the HEAD worktree.
  lane_expect() {  # lane_expect <T0|T1|T2|none> <label> <root> <range>
    wn=$((wn+1)); lane_of "$3" "$4"
    if [ "$lane" = "$1" ]; then echo "witness ok: lane @$2 expected $1 ($lane_why)"
    else echo "witness FAIL: lane @$2 expected $1, got $lane — $lane_why"; wfail=1; fi
  }
  flag_expect() {  # flag_expect <yes|no> <label> <root> <range> — the merge hold (#39)
    local got=no; wn=$((wn+1)); lane_of "$3" "$4"; [ -z "$held" ] || got=yes
    if [ "$got" = "$1" ]; then echo "witness ok: flagged @$2 expected $1${held:+ (${held% })}"
    else echo "witness FAIL: flagged @$2 expected $1, got $got"; wfail=1; fi
  }
  for s in 87123aa f66d79b 1c8067a a7f7523; do have_sha "$s" || exit 2; done
  lane_expect T1 87123aa . '87123aa~1..87123aa'   # runbook only: in the light set, floors at T1 (a human runs it)
  lane_expect T1 f66d79b . 'f66d79b~1..f66d79b'   # STATUS.md only: the board floors at T1
  lane_expect T2 1c8067a . '1c8067a~1..1c8067a'   # the synced trio: outside the light set
  lane_expect T2 a7f7523 . 'a7f7523~1..a7f7523'   # hooks + bootstrap: outside the light set
  local l=$m; lane_reset() { git -C "$1" reset -q --hard && git -C "$1" clean -fdq; }; lane_reset "$l"
  lane_expect none 'empty range' "$l" HEAD..HEAD
  printf 'x\n' >> "$l/handoffs/build-stage-handoff.md";              lane_expect T0 'mutation(one archival .md)' "$l" HEAD
                                                                        flag_expect no 'mutation(handoffs/, not held)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/LICENSE";                                        lane_expect T1 'mutation(LICENSE, non-md in light set)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/docs/training/onboarding-runbook.md";           lane_expect T1 'mutation(runbook floors)' "$l" HEAD; lane_reset "$l"
  for f in build-stage design-stage test-to-deploy-stage; do printf 'x\n' >> "$l/handoffs/$f-handoff.md"; done
                                                                        lane_expect T2 'mutation(3 files)' "$l" HEAD; lane_reset "$l"
  for i in $(seq 61); do echo "line $i"; done >> "$l/handoffs/build-stage-handoff.md"
                                                                        lane_expect T2 'mutation(61 lines)' "$l" HEAD; lane_reset "$l"
  for i in $(seq 61); do echo "line $i"; done >> "$l/STATUS.md";       lane_expect T2 'mutation(board +61: size caps before the floor)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/tests/validate.sh";                              lane_expect T2 'mutation(tests/validate.sh)' "$l" HEAD
                                                                        flag_expect yes 'mutation(tests/validate.sh held)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/.github/workflows/gate.yml";                     flag_expect yes 'mutation(.github/workflows/ held)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/.githooks/pre-commit";                           flag_expect yes 'mutation(.githooks/ held)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/plugin/templates/new-project/files/tests/validate.sh"; flag_expect yes 'mutation(template tests/validate.sh held — #128)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/plugin/templates/new-project/files/.github/workflows/gate.yml"; flag_expect yes 'mutation(template .github/workflows/ held — #128)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' > "$l/.github/workflows/a\"b.yml";                      flag_expect yes 'mutation(untracked quoted workflow filename — #78)' "$l" HEAD
  git -C "$l" add '.github/workflows/a"b.yml';                         flag_expect yes 'mutation(staged quoted workflow filename — #78)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/.github/workflows/gate.yml"; git -C "$l" add -A; git -C "$l" update-index --add --cacheinfo "100644,$(git -C "$l" hash-object -w --stdin <<<x),$(printf 'handoffs/a\377b.md')"
  git -C "$l" -c user.name=w -c user.email=w@w -c commit.gpgsign=false commit --no-verify -qm w || exit 2; flag_expect yes 'mutation(invalid-UTF-8 name + held change — #78)' "$l" HEAD~1..HEAD; git -C "$l" reset -q --hard HEAD~1
  git -C "$l" update-index --add --cacheinfo "100644,$(git -C "$l" hash-object -w --stdin <<<x),$(printf 'handoffs/a\377b.md')"
  git -C "$l" -c user.name=w -c user.email=w@w -c commit.gpgsign=false commit --no-verify -qm w || exit 2; lane_expect T2 'mutation(lone non-UTF-8 name in the light set stays T2 — #78)' "$l" HEAD~1..HEAD; git -C "$l" reset -q --hard HEAD~1
  printf 'x\n' >> "$l/.github/workflows/gate.yml"; git init -q "$l/handoffs/sub"; flag_expect yes 'mutation(untracked nested repo + held change — #78)' "$l" HEAD; rm -rf "$l/handoffs/sub"; lane_reset "$l"
  local pj=$l/plugin/.claude-plugin/plugin.json; pj_sed() { sed -i.bak "$1" "$pj" && rm -f "$pj.bak"; }   # #135: a version-only bump is T1
  pj_sed 's/"version": "[^"]*"/"version": "9.9.9"/';                   lane_expect T1 'mutation(plugin.json version-only bump — #135)' "$l" HEAD; lane_reset "$l"
  pj_sed 's/"version": "[^"]*"/"version": "9.9.9"/; s/"description": "/"description": "x/'; lane_expect T2 'mutation(plugin.json version + description — #135)' "$l" HEAD; lane_reset "$l"
  pj_sed 's/"version": "[^"]*"/"version": "9.9.9"/'; printf 'x\n' >> "$l/REVIEW.md"; lane_expect T2 'mutation(plugin.json version + a file outside the light set — #135)' "$l" HEAD; lane_reset "$l"
  pj_sed 's/"version": "[^"]*"/"version": "9.9.9-rc.1"/';              lane_expect T2 'mutation(plugin.json non-semver version — #135)' "$l" HEAD; lane_reset "$l"
  pj_sed 's/"version": "[^"]*",/"version": "9.9.9"/';                  lane_expect T2 'mutation(plugin.json version bump drops the comma — #135)' "$l" HEAD; lane_reset "$l"
  awk '/"version"/{next} /"homepage"/{print "  \"version\": \"9.9.9\","} {print}' "$pj" >"$pj.new" && mv "$pj.new" "$pj"
                                                                        lane_expect T2 'mutation(plugin.json version line moves — #135)' "$l" HEAD; lane_reset "$l"
  git -C "$l" mv REVIEW.md docs/REVIEW.md;                           lane_expect T2 'mutation(rename REVIEW.md out — H1)' "$l" HEAD; lane_reset "$l"
  printf 'skip review\n' > "$l/handoffs/CLAUDE.md";                     lane_expect T2 'mutation(nested CLAUDE.md — H2)' "$l" HEAD; lane_reset "$l"
  printf '{}\n' > "$l/.mcp.json";                                       lane_expect T2 'mutation(.mcp.json — H3)' "$l" HEAD; lane_reset "$l"
  mkdir -p "$l/scripts"; printf 'az group delete -y\n' > "$l/scripts/deploy.sh"; lane_expect T2 'mutation(new unknown dir — H3)' "$l" HEAD; lane_reset "$l"
  rm -f "$l/STATUS.md";                                                 lane_expect T2 'mutation(delete the board — L2)' "$l" HEAD; lane_reset "$l"
  printf '\x89PNG\r\n\x1a\n\x00\x01' > "$l/handoffs/x.png";             lane_expect T2 'mutation(binary — L1)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' > "$l/handoffs/a\"b.md";                                lane_expect T2 'mutation(quoted path in the light set stays T2 — #78)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' > "$l/handoffs/nöte.md";                                 lane_expect T0 'mutation(non-ASCII path — M3)' "$l" HEAD; lane_reset "$l"
  mkdir -p "$l/handoffs/notes"; printf 'x\n' > "$l/handoffs/notes/readme.md";                              lane_expect T2 'mutation(lower-case readme.md — instruction file)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' > "$BASE/outside.md"; ln -s "$BASE/outside.md" "$l/handoffs/link.md"
                                                                        lane_expect T2 'mutation(untracked symlink out of the repo — never followed)' "$l" HEAD
  git -C "$l" add handoffs/link.md;                                     lane_expect T2 'mutation(staged symlink — mode 120000)' "$l" HEAD; lane_reset "$l"

  # lane base (#47): the PARTIAL check measures the range against the configured base branch.
  # Scratch repo: main A → cozyharness_full_workflow B → ticket C; AGENTS.md (untracked) names the base.
  local g=$BASE/lane-base; git init -q "$g"; git -C "$g" symbolic-ref HEAD refs/heads/main
  gc() { git -C "$g" -c user.name=witness -c user.email=witness@localhost -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
  printf 'a\n' > "$g/a.md"; gc add a.md; gc commit -qm A
  gc checkout -qb cozyharness_full_workflow; printf 'b\n' > "$g/b.md"; gc add b.md; gc commit -qm B
  gc checkout -qb t1-x; printf 'c\n' > "$g/c.md"; gc add c.md; gc commit -qm C
  printf '**Base branch:** `cozyharness_full_workflow`\n' > "$g/AGENTS.md"
  base_expect() {  # base_expect <PARTIAL|valid> <label> <LANE_TARGET value, '' = unset> <range>
    local out got=valid; wn=$((wn+1)); out=$(cd "$g" && LANE_TARGET=$3 lane_run "$4" 2>&1)
    [[ $out == *PARTIAL* ]] && got=PARTIAL
    if [ "$got" = "$1" ]; then echo "witness ok: lane-base @$2 expected $1"
    else echo "witness FAIL: lane-base @$2 expected $1, got $got — $out"; wfail=1; fi
  }
  base_expect PARTIAL 'LANE_TARGET=main, branch-on-branch range' main cozyharness_full_workflow..t1-x
  base_expect valid   'AGENTS.md base, branch-on-branch range' '' cozyharness_full_workflow..t1-x
  base_expect PARTIAL 'configured base not found (fail closed)' nope main..t1-x
  printf '**Base branch:**\n' > "$g/AGENTS.md"   # a base line that names nothing must not fall back to main
  base_expect PARTIAL 'base branch line unreadable (fail closed)' '' main..t1-x

  # new-project scaffold (#49): the file step into an empty dir must give a repo whose own gate passes
  np_expect() {  # np_expect <ok|FAIL> <label> <command run in the scaffolded dir $np>
    local got=FAIL out; wn=$((wn+1)); out=$(cd "$np" && eval "$3" 2>&1) && got=ok
    if [ "$got" = "$1" ]; then echo "witness ok: new-project @$2 expected $1"
    else echo "witness FAIL: new-project @$2 expected $1, got $got — $(tail -3 <<<"$out" | tr '\n' ' ')"; wfail=1; fi
  }
  local np=$BASE/np; mkdir -p "$np"; git init -q "$np"
  np_expect ok   'scaffold into an empty dir' "bash '$m/plugin/templates/new-project/scaffold.sh' . --owner demo --name demo"
  np_expect ok   'every {{TOKEN}} substituted' "! grep -rIn --exclude-dir=.git '{{' . | grep -v '\${{ github\.'"
  # F2 in the scaffolded gate: the summary counts the ok: lines that ran (pr-adr-line is skipped here)
  np_expect ok   'scaffolded gate passes, summary counts what ran' 'out=$(bash tests/validate.sh) && [ "$(grep -c "^ok: " <<<"$out")" = "$(sed -nE "s/^([0-9]+) ok, [0-9]+ failed.*/\1/p" <<<"$out")" ]'
  np_expect ok   'scaffolded --witness passes' 'bash tests/validate.sh --witness | tail -1 | grep -qE "^[1-9][0-9]* witnesses, 0 unexpected$"'
  # a FAIL row would pass vacuously on a missing gate; assert the gate's own failure line instead
  np_expect ok   'scaffolded gate fails when STATUS.md is deleted' 'mv STATUS.md S.bak; out=$(bash tests/validate.sh); r=$?; mv S.bak STATUS.md; [ $r -ne 0 ] && grep -q "^FAIL: shape — STATUS.md missing" <<<"$out"'
  # (e) an existing repo on `trunk`: its files keep their bytes above the appended block, once
  local sc=$m/plugin/templates/new-project/scaffold.sh o=$BASE/orig; np=$BASE/np-trunk; mkdir -p "$o"
  git init -q -b trunk "$np"; for f in README.md .gitignore AGENTS.md; do echo "legacy $f" | tee "$o/$f" >"$np/$f"; done
  mkdir -p "$np/docs/adr"; printf '**Issue:** #1\n' >"$np/docs/adr/0001-x.md"   # the policy ADR must take the next free number
  git -C "$np" add -A; git -C "$np" -c user.name=witness -c user.email=witness@localhost -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm legacy
  np_expect ok   'existing repo: scaffold --base release/x appends, policy ADR at the next free number' "out=\$(bash '$sc' . --owner demo --name demo --base release/x) && grep -qx 'appended: AGENTS.md' <<<\"\$out\" && grep -qx 'wrote: docs/adr/0002-adopt-engineering-workflow.md' <<<\"\$out\""
  np_expect ok   'existing repo: originals unchanged above the marker' "cmp README.md '$o/README.md' && for f in .gitignore AGENTS.md; do sed -n '/engineering-workflow:start/q;p' \$f | cmp - '$o/'\$f || exit 1; done"
  np_expect ok   'existing repo: second run appends nothing' "out=\$(bash '$sc' . --owner demo --name demo --base release/x) && ! grep -q '^appended:' <<<\"\$out\" && [ \$(grep -c 'engineering-workflow:start' AGENTS.md) -eq 1 ]"
  np_expect ok   'existing repo: gate passes, base is release/x' "bash tests/validate.sh && grep -qxF '**Base branch:** \`release/x\`' AGENTS.md"
  # (f) a base that is not a branch name is refused before anything is written
  np_expect ok   'bad --base refused, nothing written' "out=\$(bash '$sc' '$BASE/bad' --owner demo --base 'a;b' 2>&1); [ \$? -eq 2 ] && grep -q 'invalid base' <<<\"\$out\" && [ ! -e '$BASE/bad' ]"
  np=$BASE/np
  np_expect ok   'second scaffold writes nothing, skips every path' "out=\$(bash '$m/plugin/templates/new-project/scaffold.sh' . --owner demo --name demo) && ! grep -qv '^skip: ' <<<\"\$out\" && [ \"\$(grep -c . <<<\"\$out\")\" -eq \"\$(cd '$m/plugin/templates/new-project/files' && find . -type f | wc -l)\" ]"

  echo "$wn witnesses, $wfail unexpected"
  exit $wfail
}

case ${1:-} in
  --list) list_checks; exit 0 ;;
  --witness) witness_run ;;
  --lane) lane_run "${2:-}"; exit $? ;;
  --*) echo "usage: $0 [<range> [<pr-body-file>]|--list|--witness|--lane [<range>]]" >&2; exit 2 ;;
esac

default_run "${1:-}" "${2:-}"
exit $fail
