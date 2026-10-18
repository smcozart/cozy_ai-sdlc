#!/usr/bin/env bash
# scaffolded from ai-sdlc--v{{PLUGIN_VERSION}}
# The Test gate: one command, one exit code, one line per check.
#
#   tests/validate.sh [<range>]         run every check; print the lane and flagged lines for <range> (else dirty tree, else HEAD~1..HEAD)
#   tests/validate.sh <range> <pr-body-file>  also run pr-adr-line on the PR body (CI passes it; skipped without it)
#   tests/validate.sh --list            print check names, one per line
#   tests/validate.sh --witness         prove each check fails on its bad case (mutations on a temp copy)
#   tests/validate.sh --lane [<range>]  classify the diff's review lane (T0/T1/T2) and merge hold from what git sees
#
# Requires: bash, git, grep/sed/awk. Offline. Never mutates the working tree.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE  # a hook-exported GIT_DIR makes rev-parse return cwd (tests/), not the root
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 2
CHECKS="shape intent-layout adr-numbering app-tests pr-adr-line"

# ---------- lane classifier (Deploy: review effort follows the lane) ----------
# A classifier, not a check: it prints one `lane:` line and one `flagged:` line to paste beside the
# gate run. It is an ALLOW-list — only paths in LANE_LIGHT may take a reduced budget; everything else,
# including every path this repo has not grown yet, is T2. Renames are read as delete+add (--no-renames)
# so a move out of a protected path is the delete it is; every path is read NUL-separated (-z) so git never
# quotes it (core.quotePath=off still quotes `"`, `\`, control chars) and LANE_HOLD sees the real path.
# Instruction files (LANE_NEVER, any case) are T2 wherever they sit; deletes, binaries and symlinks are T2
# (a symlink is never followed — its target may sit outside the repo). The agent still
# confirms "earns no ADR" and "not speculative", and may only ESCALATE the printed lane.
# Extend LANE_LIGHT (safe by omission) and LANE_FLOOR_T1 (light files a session acts on).
# LANE_HOLD is the merge hold list: the files that enforce the gate. `flagged: yes` = a human merges.
LANE_LIGHT='^(handoffs/|STATUS\.md$|LICENSE$)'
# A range ending at HEAD whose paths (and dirty tree) are all in RECORDS_ONLY skips app-tests. Widen it like LANE_LIGHT;
# RECORDS_ONLY='' always runs them (a repo whose tests read records).
RECORDS_ONLY='^(intent/|handoffs/|STATUS\.md$)'
LANE_FLOOR_T1='^(STATUS\.md$)'   # README.md anywhere is LANE_NEVER (T2), never a floor entry
LANE_NEVER='(^|/)(CLAUDE|AGENTS|GEMINI|COPILOT|README)\.md$|(^|/)\.(cursorrules|mcp\.json|gitmodules)$'
LANE_HOLD='^(tests/validate\.sh$|\.github/workflows/|\.githooks/)'
LANE_MAX_FILES=2; LANE_MAX_LINES=60
lane_of() {  # lane_of <root> <range> -> sets lane (T0|T1|T2|none), lane_why and held; rc 2 when there is no lane
  local r=$1 range=$2 st files n never outside del ns lines bin untracked="" o links raw
  local -x LC_ALL=C   # paths are bytes: a UTF-8 locale makes tr/cut abort on an invalid byte and drop the hold
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
  raw=$(git -C "$r" diff -z --no-renames --raw "$range" | tr '\n\0' '\t\n' | paste - -)
  links=$(awk -F'\t' '$1 ~ / 120000 |^:120000 / {print $2}' <<<"$raw" | tr '\n' ' ')
  # a path git would quote (`"`, `\`, control char) or that is not UTF-8 is never light: the real name must not lower the lane (escalate only)
  outside=$({ grep -vE "$LANE_LIGHT" <<<"$files"; grep -E "$LANE_LIGHT" <<<"$files" | grep -E '["\\[:cntrl:]]'; iconv -f UTF-8 -t UTF-8 <<<"$files" >/dev/null 2>&1 || echo '(a non-UTF-8 path)'; } | tr '\n' ' ')
  ns=$(git -C "$r" diff -z --no-renames --numstat "$range" | tr '\n\0' '\t\n' | awk -F'\t' '$1=="-"||$2=="-"{b=1} {a+=$1; d+=$2} END{print a+d+0, b+0}')
  lines=${ns%% *}; bin=${ns##* }
  while IFS= read -r -d '' o; do   # untracked, real names: count lines ourselves, NUL byte = binary; never follow a symlink
    if [ -L "$r/$o" ]; then links="$links$o "
    elif [ ! -f "$r/$o" ] || [ ! -r "$r/$o" ]; then bin=1   # not a readable regular file (an untracked nested repo lists as dir/): never counted, T2
    elif [ "$(head -c 8000 "$r/$o" | tr -d '\000' | wc -c)" -ne "$(head -c 8000 "$r/$o" | wc -c)" ]; then bin=1; else lines=$((lines + $(wc -l <"$r/$o"))); fi
  done < <([ "$range" != HEAD ] || git -C "$r" ls-files -z --others --exclude-standard)
  lane_files=$files; lane_risky="$del$links$(awk -F'\t' '$1 ~ / 160000 |^:160000 / {print $2}' <<<"$raw")"   # for records_only: deletes, symlinks, submodules
  if   [ -n "$never" ];                       then lane=T2; lane_why="instruction file: ${never% }"
  elif [ -n "$outside" ];                     then lane=T2; lane_why="outside the light set: ${outside% }"
  elif [ -n "$links" ];                       then lane=T2; lane_why="symlink (not followed): ${links% }"
  elif [ -n "$del" ];                         then lane=T2; lane_why="deletes: ${del% }"
  elif [ "$bin" = 1 ];                        then lane=T2; lane_why="binary file in range"
  elif [ "$n" -gt "$LANE_MAX_FILES" ];        then lane=T2; lane_why="$n files (>$LANE_MAX_FILES)"
  elif [ "$lines" -gt "$LANE_MAX_LINES" ];    then lane=T2; lane_why="$lines changed lines (>$LANE_MAX_LINES)"
  elif grep -qE "$LANE_FLOOR_T1" <<<"$files"; then lane=T1; lane_why="floors at T1 ($(grep -E "$LANE_FLOOR_T1" <<<"$files" | tr '\n' ' ' | sed 's/ $//')): a session acts on it"
  elif ! grep -qvE '\.md$' <<<"$files";       then lane=T0; lane_why="$n file(s), docs-only, $lines lines, all in the light set"
  else                                           lane=T1; lane_why="$n file(s), $lines changed lines, all in the light set"
  fi
}
base_of() {  # base_of <tip> -> sets the caller's bl (base line), t (base branch), hit (its ref) and base (merge-base of hit and <tip>)
  local m refs="origin/main main"; hit=""; base=""
  # the base branch: LANE_TARGET overrides AGENTS.md's **Base branch:** line; neither set = main
  bl=$(grep -m1 '^\*\*Base branch' AGENTS.md 2>/dev/null | tr -d '\r')
  t=${LANE_TARGET:-$(sed -nE 's/^\*\*Base branch:\*\*[[:space:]]*`?([^`[:space:]]+)`?.*/\1/p' <<<"$bl")}
  [ -z "$t" ] || refs="origin/$t $t"
  for m in $refs; do git rev-parse -q --verify "$m^{commit}" >/dev/null 2>&1 && { hit=$m; base=$(git merge-base "$m" "$1" 2>/dev/null); break; }; done
}
lane_run() {  # lane_run [<range>] -> prints the lane and flagged lines with resolved shas; exit 0 on a lane, 2 on none
  local range=${1:-} a b hit base shown partial="" t bl
  # dirty = tracked changes OR untracked files; a new file alone must not fall through to HEAD~1..HEAD
  if [ -z "$range" ]; then if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then range=HEAD; else range=HEAD~1..HEAD; fi; fi
  lane_of . "$range"; lane_why=${lane_why//[[:cntrl:]]/?}; held=${held//[[:cntrl:]]/?}   # raw names: no control char reaches the terminal
  if [ "$range" = HEAD ]; then shown="dirty tree vs $(git rev-parse --short HEAD)"
  elif [[ $range == *..* ]]; then
    a=$(git rev-parse --short "${range%%..*}" 2>/dev/null); b=$(git rev-parse --short "${range##*..}" 2>/dev/null); shown="$a..$b"
    base_of "${range##*..}"
    # a partial range hides files: the close needs the ticket's full range, i.e. merge-base(base, tip)..tip
    # a configured base fails closed: unreadable line, no ref, or no common history all print PARTIAL
    if [ -z "$t" ] && [ -n "$bl" ]; then partial=" — PARTIAL RANGE (base branch line in AGENTS.md unreadable); not valid for a close"
    elif [ -n "$base" ] && [ "$(git rev-parse "${range##*..}")" != "$(git rev-parse "$hit")" ] \
       && [ "$(git rev-parse "${range%%..*}" 2>/dev/null)" != "$base" ]; then partial=" — PARTIAL RANGE (base is not the merge-base with $hit); not valid for a close"
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
records_only() {  # records_only <range>: rc 0 when app-tests may skip — every path in the range and the working tree is a record
  local range=$1 p hit base t bl; local -x LC_ALL=C
  # the tests run on the working tree, so the range is the whole ticket: merge-base(base branch, HEAD)..HEAD; any doubt runs them
  [ -n "$RECORDS_ONLY" ] && [[ $range == *..HEAD ]] || return 1
  base_of HEAD; [ -n "$t" ] || [ -z "$bl" ] || return 1
  [ -n "$base" ] && [ "$(git rev-parse -q --verify "${range%%..*}^{commit}")" = "$base" ] || return 1
  lane_of . "$range" && [ -z "$lane_risky" ] || return 1
  p=$(printf '%s\n' "$lane_files"; git status --porcelain -z --no-renames -unormal | tr '\n\0' '\t\n' | cut -c4-)
  ! grep -qvE "$RECORDS_ONLY" <<<"$p"
}

# ---------- checks: check_<name> <root> (pr-adr-line: <file>); on failure set why and return 1 ----------
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

check_pr_adr_line() {  # every PR body carries an ADR: line (presence only); a fenced line is quoted text, not the PR's own
  awk '/^[[:space:]]*(```|~~~)/{f=!f; next} !f' "$1" | grep -qE '^ADR:[[:space:]]*[^[:space:]]' || { why="$1: no 'ADR:' line (write 'ADR: none' when the PR records no decision)"; return 1; }
}

# ---------- runner ----------
fail=0; fail_count=0; ran_ok=0; why=""   # ran_* counts what actually ran: the summary must not derive from --list
run() {  # run <name> <arg>
  why=""
  if "check_${1//-/_}" "$2"; then echo "ok: $1${why:+ ($why)}"; ran_ok=$((ran_ok+1))
  else echo "FAIL: $1 — $why"; fail=1; fail_count=$((fail_count+1)); fi
}
default_run() {
  local c body=${2:-}
  # a range git cannot read is an error, never a silent pass (an empty range is fine: lane none, exit 0)
  if [ -n "${1:-}" ] && ! git diff --name-only "$1" >/dev/null 2>&1; then
    echo "range: git diff $1 failed — fix the range (bad ref, or a shallow clone: git fetch --unshallow)"; exit 2
  fi
  for c in shape intent-layout adr-numbering; do run "$c" .; done
  if [ -n "${1:-}" ] && records_only "$1"; then echo "skipped: app-tests — records-only diff"; else run app-tests .; fi
  if [ -n "$body" ]; then run pr-adr-line "$body"; else echo "skipped: pr-adr-line — no PR body file given (CI passes one)"; fi
  echo "$ran_ok ok, $fail_count failed"
  if ! git rev-parse -q --verify HEAD >/dev/null; then echo "lane: none — no commits yet"
  elif [ -z "${1:-}" ] && ! git rev-parse -q --verify HEAD~1 >/dev/null && git diff --quiet HEAD && [ -z "$(git ls-files --others --exclude-standard)" ]; then echo "lane: none — first commit, nothing to compare yet"
  else lane_run "${1:-}" || true; fi   # trailer, not a check: one paste carries both
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
  expect() {  # expect <ok|FAIL> <label> <check> [<arg>, default the temp copy]
    local got=FAIL; wn=$((wn+1)); why=""
    "check_${3//-/_}" "${4:-$m}" && got=ok
    if [ "$got" = "$1" ]; then echo "witness ok: $3 @$2 expected $1${why:+ ($why)}"
    else echo "witness FAIL: $3 @$2 expected $1, got $got${why:+ — $why}"; wfail=1; fi
  }
  local c; fresh; for c in shape intent-layout adr-numbering app-tests; do expect ok baseline "$c"; done
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
  printf 'Summary\n\nADR: none\n' >"$base/body";                  expect ok 'PR body, ADR: none' pr-adr-line "$base/body"
  printf 'Summary\n\nNo decision line.\n' >"$base/body";          expect FAIL 'PR body, no ADR: line' pr-adr-line "$base/body"
  printf 'Summary\n\n```\nADR: none\n```\n' >"$base/body";        expect FAIL 'PR body, ADR: line only fenced' pr-adr-line "$base/body"

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
  mkdir -p "$g/.github/workflows"; printf 'x\n' >"$g/.github/workflows/x.yml"
  is 'flagged @a .github/workflows/ file expected yes' 'lane_of "$g" HEAD; [ -n "$held" ]'

  # records-only skip: scratch repo whose app tests fail, so `FAIL: app-tests` means they ran; rec = origin/main + records
  g=$base/r; fresh; cp -R "$m" "$g"; mkdir -p "$g/src" "$g/handoffs"; printf 'x\n' | tee "$g/src/a.js" >"$g/handoffs/h.md"
  printf '**App tests:** `false`\n' >>"$g/AGENTS.md"; git init -q "$g"; gc symbolic-ref HEAD refs/heads/main
  gc add -A; gc commit -qm base; gc update-ref refs/remotes/origin/main HEAD
  gc checkout -qb rec; printf 'x\n' >"$g/intent/x.md"; printf 'x\n' >>"$g/STATUS.md"; gc add -A; gc commit -qm rec
  gate() { (cd "$g" && LANE_TARGET=main default_run "$1"; exit $fail); }   # LANE_TARGET: the scratch base is main whatever this repo's is
  ran() { local out; out=$(gate "$1"); grep -q '^FAIL: app-tests' <<<"$out"; }
  is 'app-tests @records-only range expected skipped, not counted' 'out=$(gate origin/main..HEAD) && grep -qx "skipped: app-tests — records-only diff" <<<"$out" && grep -q "^3 ok, 0 failed" <<<"$out"'
  is 'app-tests @no range expected run' 'ran ""'
  is 'app-tests @range end not HEAD expected run' 'ran main..rec'
  is "app-tests @RECORDS_ONLY='' expected run" 'RECORDS_ONLY= ran origin/main..HEAD'
  printf 'x\n' >"$g/src/x.js"; is 'app-tests @untracked src/x.js expected run' 'ran origin/main..HEAD'; rm "$g/src/x.js"
  printf 'x\n' >>"$g/STATUS.md"; is 'app-tests @bare HEAD, only STATUS.md dirty expected run' 'ran HEAD'; gc checkout -q -- STATUS.md
  is 'app-tests @base branch not found expected run' 'out=$(cd "$g" && LANE_TARGET=nope default_run origin/main..HEAD); grep -q "^FAIL: app-tests" <<<"$out"'
  printf 'x\n' >"$g/src/b.js"; gc add -A; gc commit -qm code; printf 'x\n' >>"$g/STATUS.md"; gc commit -qam board
  is 'app-tests @HEAD~1..HEAD, start not the merge-base expected run' 'ran HEAD~1..HEAD'; gc reset -q --hard HEAD~2
  one() {  # one <label> <step>: commit the step on rec; app-tests must run on origin/main..HEAD; drop it
    eval "$2"; gc add -A; gc commit -qm "$1"; is "app-tests @$1 expected run" 'ran origin/main..HEAD'; gc reset -q --hard HEAD~1
  }
  one 'plus one code file' 'printf "x\n" >"$g/src/b.js"'
  one 'deletes a file' 'rm "$g/handoffs/h.md"'
  one 'rename code into intent/' 'gc mv src/a.js intent/a.js'
  one 'symlink under intent/' 'ln -s ../STATUS.md "$g/intent/l"'
  local nl=$'\n'; one 'newline in a path' 'mkdir "$g/STATUS.md${nl}intent" && printf "x\n" >"$g/STATUS.md${nl}intent/x"'
  echo "$wn witnesses, $wfail unexpected"
  exit $wfail
}

case ${1:-} in
  --list) printf '%s\n' $CHECKS; exit 0 ;;
  --witness) witness_run ;;
  --lane) lane_run "${2:-}"; exit $? ;;
  --*) echo "usage: $0 [<range> [<pr-body-file>]|--list|--witness|--lane [<range>]]" >&2; exit 2 ;;
esac
default_run "${1:-}" "${2:-}"
exit $fail
