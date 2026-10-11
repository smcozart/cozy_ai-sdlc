#!/usr/bin/env bash
# scaffolded from engineering-workflow--v{{PLUGIN_VERSION}}
# The Test gate: one command, one exit code, one line per check.
#
#   tests/validate.sh [<range>]         run every check; print the lane line for <range> (else dirty tree, else HEAD~1..HEAD)
#   tests/validate.sh --list            print check names, one per line
#   tests/validate.sh --witness         prove each check fails on its bad case (mutations on a temp copy)
#   tests/validate.sh --lane [<range>]  classify the diff's review lane (T0/T1/T2) from what git sees
#
# Requires: bash, git, grep/sed/awk. Offline. Never mutates the working tree.
set -uo pipefail
# a hook may export GIT_DIR; drop it so the root is this checkout's, also in a worktree
cd "$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 2
CHECKS="shape intent-layout adr-numbering app-tests"

# ---------- lane classifier (Deploy: review effort follows the lane) ----------
# A classifier, not a check: it prints one `lane:` line to paste beside the gate run. It is an
# ALLOW-list — only paths in LANE_LIGHT may take a reduced budget; everything else is T2. Renames are
# read as delete+add (--no-renames); quotePath is off so non-ASCII paths still match. Instruction
# files (LANE_NEVER) are T2 wherever they sit; deletes and binaries are T2. Escalate only.
LANE_LIGHT='^(handoffs/|STATUS\.md$|LICENSE$)'
LANE_FLOOR_T1='^(STATUS\.md$)'   # light files a session acts on
LANE_NEVER='(^|/)(CLAUDE|AGENTS|GEMINI|COPILOT|README)\.md$|(^|/)\.(cursorrules|mcp\.json|gitmodules)$'
LANE_MAX_FILES=2; LANE_MAX_LINES=60
lane_of() {  # lane_of <root> <range> -> sets lane (T0|T1|T2|none) and lane_why; rc 2 when there is no lane
  local r=$1 range=$2 st files n never outside del ns lines bin untracked="" o
  st=$(git -C "$r" -c core.quotePath=off diff --no-renames --name-status "$range" 2>/dev/null) || { lane=none; lane_why="git diff $range failed — fix the range"; return 2; }
  # the dirty tree includes untracked files; `git diff HEAD` does not list them, so a new file would otherwise vanish from the lane
  [ "$range" != HEAD ] || untracked=$(git -C "$r" -c core.quotePath=off ls-files --others --exclude-standard)
  [ -n "$st$untracked" ] || { lane=none; lane_why="empty range — fix the range"; return 2; }
  files=$({ [ -z "$st" ] || cut -f2- <<<"$st"; [ -z "$untracked" ] || printf '%s
' "$untracked"; }); n=$(grep -c . <<<"$files")
  del=$(awk -F'\t' '$1 ~ /^D/ {print $2}' <<<"$st" | tr '\n' ' ')
  never=$(grep -E "$LANE_NEVER" <<<"$files" | tr '\n' ' ')
  outside=$(grep -vE "$LANE_LIGHT" <<<"$files" | tr '\n' ' ')
  ns=$(git -C "$r" -c core.quotePath=off diff --no-renames --numstat "$range" | awk -F'\t' '$1=="-"||$2=="-"{b=1} {a+=$1; d+=$2} END{print a+d+0, b+0}')
  lines=${ns%% *}; bin=${ns##* }
  while IFS= read -r o; do [ -n "$o" ] || continue   # untracked: count lines ourselves, NUL byte = binary
    if [ "$(head -c 8000 "$r/$o" | tr -d '\000' | wc -c)" -ne "$(head -c 8000 "$r/$o" | wc -c)" ]; then bin=1; else lines=$((lines + $(wc -l <"$r/$o"))); fi
  done <<<"$untracked"
  if   [ -n "$never" ];                       then lane=T2; lane_why="instruction file: ${never% }"
  elif [ -n "$outside" ];                     then lane=T2; lane_why="outside the light set: ${outside% }"
  elif [ -n "$del" ];                         then lane=T2; lane_why="deletes: ${del% }"
  elif [ "$bin" = 1 ];                        then lane=T2; lane_why="binary file in range"
  elif [ "$n" -gt "$LANE_MAX_FILES" ];        then lane=T2; lane_why="$n files (>$LANE_MAX_FILES)"
  elif [ "$lines" -gt "$LANE_MAX_LINES" ];    then lane=T2; lane_why="$lines changed lines (>$LANE_MAX_LINES)"
  elif grep -qE "$LANE_FLOOR_T1" <<<"$files"; then lane=T1; lane_why="floors at T1 ($(grep -E "$LANE_FLOOR_T1" <<<"$files" | tr '\n' ' ' | sed 's/ $//')): a session acts on it"
  elif ! grep -qvE '\.md$' <<<"$files";       then lane=T0; lane_why="$n file(s), docs-only, $lines lines, all in the light set"
  else                                           lane=T1; lane_why="$n file(s), $lines changed lines, all in the light set"
  fi
}
lane_run() {  # lane_run [<range>] -> prints the lane line with resolved shas; exit 0 on a lane, 2 on none
  local range=${1:-} a b m hit="" base="" shown partial="" t bl refs="origin/main main"
  # the base branch: LANE_TARGET overrides AGENTS.md's **Base branch:** line; neither set = main, as before
  bl=$(grep -m1 '^\*\*Base branch' AGENTS.md 2>/dev/null | tr -d '\r')
  t=${LANE_TARGET:-$(sed -nE 's/^\*\*Base branch:\*\*[[:space:]]*`?([^`[:space:]]+)`?.*/\1/p' <<<"$bl")}
  [ -z "$t" ] || refs="origin/$t $t"
  # dirty = tracked changes OR untracked files; a new file alone must not fall through to HEAD~1..HEAD
  if [ -z "$range" ]; then if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then range=HEAD; else range=HEAD~1..HEAD; fi; fi
  lane_of . "$range"
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
  [ "$lane" = T2 ] || echo "confirm at close (fill in): no-ADR=<y/n> not-speculative=<y/n> — any n means T2. Escalate only."
  return 0
}

# ---------- checks: check_<name> <root>; on failure set why and return 1 ----------
check_shape() {
  local f; for f in AGENTS.md STATUS.md CONTEXT.md REVIEW.md intent/TEMPLATE.md; do [ -f "$1/$f" ] || { why="$f missing"; return 1; }; done
}

check_intent_layout() {
  local r=$1 d n slug got
  for d in "$r"/intent/*/; do
    [ -d "$d" ] || continue   # no work-item folders yet
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

check_app_tests() {  # runs the command on AGENTS.md's **App tests:** line; no line = no app tests yet
  local r=$1 line cmd out
  line=$(grep -m1 -E '^[[:space:]]*([-*+][[:space:]]+)?\*\*App tests(:\*\*|\*\*:)' "$r/AGENTS.md" 2>/dev/null)   # indent, a list bullet, either colon place
  [ -n "$line" ] || { why="none yet — name the command in AGENTS.md when the stack ADR lands"; return 0; }
  cmd=$(sed -nE 's/^[[:space:]]*([-*+][[:space:]]+)?\*\*App tests(:\*\*|\*\*:)[[:space:]]*`([^`]+)`.*/\3/p' <<<"$line")
  [ -n "$cmd" ] || { why="AGENTS.md **App tests:** line names no command in backticks"; return 1; }
  out=$(cd "$r" && bash -c "$cmd" 2>&1) || { why="\`$cmd\` failed: $(tail -1 <<<"$out")"; return 1; }
}

# ---------- runner ----------
fail=0; fail_count=0; why=""
run() {  # run <name> <root>
  why=""
  if "check_${1//-/_}" "$2"; then echo "ok: $1${why:+ ($why)}"
  else echo "FAIL: $1 — $why"; fail=1; fail_count=$((fail_count+1)); fi
}
default_run() {
  local c n
  # a range git cannot read is an error, never a silent pass (an empty range is fine: lane none, exit 0)
  if [ -n "${1:-}" ] && ! git diff --name-only "$1" >/dev/null 2>&1; then
    echo "range: git diff $1 failed — fix the range (bad ref, or a shallow clone: git fetch --unshallow)"; exit 2
  fi
  for c in $CHECKS; do run "$c" .; done
  if ! git rev-parse -q --verify HEAD >/dev/null; then echo "lane: none — no commits yet"
  elif [ -z "${1:-}" ] && ! git rev-parse -q --verify HEAD~1 >/dev/null && git diff --quiet HEAD && [ -z "$(git ls-files --others --exclude-standard)" ]; then echo "lane: none — first commit, nothing to compare yet"
  else lane_run "${1:-}" || true; fi   # trailer, not a check: one paste carries both
  n=$(wc -w <<<"$CHECKS" | tr -d ' ')
  echo "$((n - fail_count)) ok, $fail_count failed"
}

# ---------- witness: each check, on a temp copy, fails on its bad case ----------
witness_run() {
  local m wn=0 wfail=0 base
  base=$(mktemp -d "${TMPDIR:-/tmp}/validate.XXXXXX"); trap 'rm -rf "$base"' EXIT; m=$base/m
  fresh() {  # a copy of what the checks read; the app-test command is dropped (it needs the whole repo)
    rm -rf "$m"; mkdir -p "$m/docs"
    cp -R AGENTS.md STATUS.md CONTEXT.md REVIEW.md intent "$m"/ && cp -R docs/adr "$m/docs/"
    grep -vE '^[[:space:]]*([-*+][[:space:]]+)?\*\*App tests(:\*\*|\*\*:)' AGENTS.md >"$m/AGENTS.md"
  }
  expect() {  # expect <ok|FAIL> <label> <check>
    local got=FAIL; wn=$((wn+1)); why=""
    "check_${3//-/_}" "$m" && got=ok
    if [ "$got" = "$1" ]; then echo "witness ok: $3 @$2 expected $1${why:+ ($why)}"
    else echo "witness FAIL: $3 @$2 expected $1, got $got${why:+ — $why}"; wfail=1; fi
  }
  local c; fresh; for c in $CHECKS; do expect ok baseline "$c"; done
  rm "$m/STATUS.md";                                               expect FAIL 'STATUS.md deleted' shape; fresh
  mkdir -p "$m/intent/1-x"; printf '**Issue:** #1\n' >"$m/intent/1-x/intent.md"; expect ok 'intent cites its issue' intent-layout
  printf '**Issue:** #2\n' >"$m/intent/1-x/intent.md";            expect FAIL 'intent cites another issue' intent-layout; fresh
  : >"$m/docs/adr/$(printf %04d 9)-gap.md";                       expect FAIL 'ADR number gap' adr-numbering; fresh
  printf '**App tests:** `true`\n' >>"$m/AGENTS.md";              expect ok 'app tests pass' app-tests; fresh
  printf '**App tests:** `false`\n' >>"$m/AGENTS.md";             expect FAIL 'app tests fail' app-tests; fresh
  printf -- '- **App tests:** `false`\n' >>"$m/AGENTS.md";          expect FAIL 'app tests fail, list-bullet line' app-tests; fresh
  printf -- '  + **App tests**: `false`\n' >>"$m/AGENTS.md";         expect FAIL 'app tests fail, indented + bullet, colon outside the bold' app-tests; fresh
  printf '**App tests:** false\n' >>"$m/AGENTS.md";               expect FAIL 'app tests line without backticks' app-tests; fresh
  printf '# x\n' >"$m/docs/adr/$(printf %04d 2)-no-issue.md";     expect FAIL 'ADR without an Issue header' adr-numbering; fresh
  mkdir -p "$m/intent/1-x"; printf '**Issue:** #1\n' >"$m/intent/1-x/intent.md"
  printf '**Issue:** #2 · **Intent:** `intent/1-x/intent.md`\n' >"$m/intent/1-x/spec.md"; expect FAIL 'spec cites another issue' intent-layout; fresh

  # lane classifier: scratch repo main A -> ticket branch t1-x C
  local g=$base/g; git init -q "$g"; git -C "$g" symbolic-ref HEAD refs/heads/main
  gc() { git -C "$g" -c user.name=witness -c user.email=witness@localhost -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
  printf 'a\n' >"$g/a.md"; gc add a.md; gc commit -qm A
  gc checkout -qb t1-x; printf 'c\n' >"$g/c.md"; gc add c.md; gc commit -qm C
  is() {  # is <label> <command>: a row that passes when the command succeeds
    wn=$((wn+1)); if eval "$2" >/dev/null 2>&1; then echo "witness ok: $1"; else echo "witness FAIL: $1"; wfail=1; fi
  }
  is 'lane @configured base not found expected PARTIAL' '(cd "$g" && LANE_TARGET=nope lane_run main..t1-x) | grep -q "PARTIAL RANGE (base branch nope not found)"'
  is 'lane @empty range expected none' 'lane_of "$g" HEAD..HEAD; [ "$lane" = none ]'
  echo "$wn witnesses, $wfail unexpected"
  exit $wfail
}

case ${1:-} in
  --list) printf '%s\n' $CHECKS; exit 0 ;;
  --witness) witness_run ;;
  --lane) lane_run "${2:-}"; exit $? ;;
  --*) echo "usage: $0 [<range>|--list|--witness|--lane [<range>]]" >&2; exit 2 ;;
esac
default_run "${1:-}"
exit $fail
