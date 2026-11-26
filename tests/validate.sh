#!/usr/bin/env bash
# The Test gate: one command, one exit code, one line per check.
# The requirement: ADR 0008 and the work-item intents (intent/<n>-<slug>/intent.md) that added each check.
#
#   tests/validate.sh [<range>]   run every check; print the range and flagged lines for <range> (else dirty tree, else HEAD~1..HEAD)
#   tests/validate.sh --list      print check names, one per line
#   tests/validate.sh --witness   run every fail-first witness (needs full history)
#   tests/validate.sh --lane [<range>]  print the range and the merge hold (flagged: yes|no) from what git sees (ADR 0005)
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
CHECKS="intent-layout adr-numbering adr-refs skill-frontmatter skill-links template-gate-parity agents-commands"

fail=0; why=""
list_checks() { printf '%s\n' $CHECKS; }

# ---------- merge hold (ADR 0005; one review lane, ADR 0008) ----------
# A classifier, not a check: it prints one `range:` line and one `flagged:` line to paste beside the
# gate run. LANE_HOLD is the merge hold list: the files that check other files. `flagged: yes` = a human merges.
# Renames are read as delete+add (--no-renames) so a move out of a held path is the delete it is; every path is
# read NUL-separated (-z) so git never quotes it (#78: core.quotePath=off still quotes `"`, `\`, control chars)
# and LANE_HOLD sees the real path.
LANE_HOLD='^(tests/validate\.sh$|\.github/workflows/|\.githooks/|plugin/templates/new-project/files/tests/validate\.sh$|plugin/templates/new-project/files/\.github/workflows/|plugin/templates/new-project/scaffold\.sh$)'
lane_of() {  # lane_of <root> <range> -> sets held; rc 2 (lane_why says why) when there is no range to read
  local r=$1 range=$2 st untracked=""
  local -x LC_ALL=C   # paths are bytes: a UTF-8 locale makes tr/grep abort on an invalid byte and drop the hold (#78)
  held=""; lane_why=""
  [[ $range != -* ]] || { lane_why="usage: tests/validate.sh --lane [<range>] — a range never starts with - (git diff would read it as an option)"; return 2; }
  # -z output, one path per line: NUL ends the path, a newline inside a path becomes a tab
  st=$(git -C "$r" diff -z --no-renames --name-only "$range" 2>/dev/null | tr '\n\0' '\t\n') || { lane_why="git diff $range failed — fix the range"; return 2; }
  # the dirty tree includes untracked files; `git diff HEAD` does not list them, so a new file would otherwise vanish from the hold
  [ "$range" != HEAD ] || untracked=$(git -C "$r" ls-files -z --others --exclude-standard | tr '\n\0' '\t\n')
  [ -n "$st$untracked" ] || { lane_why="empty range — fix the range"; return 2; }
  held=$(printf '%s\n%s\n' "$st" "$untracked" | grep -E "$LANE_HOLD" | tr '\n' ' ') || true   # no held path is not an error
}
lane_run() {  # lane_run [<range>] -> prints the range and flagged lines with resolved shas; exit 0, or 2 when there is no range
  local range=${1:-} a b m hit="" base="" shown partial="" t bl rc refs="origin/main main"
  # the base branch: LANE_TARGET overrides AGENTS.md's **Base branch:** line; neither set = main, as before (#47)
  bl=$(grep -m1 '^\*\*Base branch' AGENTS.md 2>/dev/null | tr -d '\r')
  t=${LANE_TARGET:-$(sed -nE 's/^\*\*Base branch:\*\*[[:space:]]*`?([^`[:space:]]+)`?.*/\1/p' <<<"$bl")}
  [ -z "$t" ] || refs="origin/$t $t"
  # dirty = tracked changes OR untracked files; a new file alone must not fall through to HEAD~1..HEAD
  if [ -z "$range" ]; then if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then range=HEAD; else range=HEAD~1..HEAD; fi; fi
  lane_of . "$range"; rc=$?; lane_why=${lane_why//[[:cntrl:]]/?}; held=${held//[[:cntrl:]]/?}   # raw names: no control char reaches the terminal
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
  [ "$rc" = 0 ] || { echo "range: none — $lane_why ($shown)"; return 2; }
  echo "range: $shown$partial"
  if [ -n "$held" ]; then echo "flagged: yes — merge hold, a human merges: ${held% }"; else echo "flagged: no"; fi
  return 0
}

# ---------- static half: check_<name> <root> ----------
check_intent_layout() {
  local r=$1 d n slug got
  for d in "$r"/intent/*/; do
    d=${d%/}; slug=${d##*/}
    [[ $slug =~ ^[0-9]+-[a-z0-9-]+$ ]] || { why="intent/$slug: bad dir name"; return 1; }
    n=${slug%%-*}
    [ -f "$d/intent.md" ] || { why="intent/$slug/intent.md missing"; return 1; }
    got=$(grep -oE '^\*\*Issue:\*\* #[0-9]+' "$d/intent.md" | head -1 | grep -oE '[0-9]+$')
    [ "$got" = "$n" ] || { why="intent/$slug/intent.md: expected **Issue:** #$n, found #${got:-none}"; return 1; }
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

check_template_gate_parity() {  # the scaffolded gate must hold like this one: same staged diff, same range:/flagged: lines
  local r=$1 t=$1/plugin/templates/new-project/files d f p a b rc=0
  cmp -s "$r/.pi/agents/adversary.md" "$t/.pi/agents/adversary.md" \
    || { why=".pi/agents/adversary.md and its template copy differ (must be byte-identical)"; return 1; }
  d=$(mktemp -d "${TMPDIR:-/tmp}/parity.XXXXXX"); mkdir -p "$d/tests"   # a temp repo, never a worktree
  cp "$r/tests/validate.sh" "$d/tests/validate.sh" && cp "$t/tests/validate.sh" "$d/tests/template.sh" && git -C "$d" init -q && git -C "$d" add -A \
    && git -C "$d" -c user.name=parity -c user.email=parity@localhost -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm base \
    || { why="cannot build the temp repo in $d"; rm -rf "$d"; return 1; }
  for f in 'tests/validate.sh .githooks/x .github/workflows/a"b.yml' handoffs/x.md; do   # every shared hold alternative + a name git quotes, then a light path
    for p in $f; do mkdir -p "$d/${p%/*}"; printf '# x\n' >>"$d/$p"; git -C "$d" add "$p"; done
    a=$(bash "$d/tests/validate.sh" --lane | grep -E '^(range|flagged):'); b=$(bash "$d/tests/template.sh" --lane | grep -E '^(range|flagged):')
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

# ---------- runner ----------
verdict() {  # verdict <name> <arg> -> sets v=ok|FAIL and why (no subshell: why must survive)
  local name=$1; shift; why=""; v=FAIL
  if [ -f "$1" ] || [ -d "$1" ]; then
    "check_${name//-/_}" "$@" && v=ok
  else why="$1: file missing"; fi
}
fail_count=0; ran_ok=0  # ran_* counts what actually ran (F2: the summary must not derive from --list)
run() {
  verdict "$@"
  case $v in ok) echo "ok: $1"; ran_ok=$((ran_ok+1)) ;; *) echo "FAIL: $1 — $why"; fail=1; fail_count=$((fail_count+1)) ;; esac
}

default_run() {
  local range=${1:-}
  if [ -z "$range" ]; then
    if ! git diff --quiet HEAD 2>/dev/null; then range=HEAD; else range=HEAD~1..HEAD; fi
  fi
  # a range git cannot read is an error, never a silent pass
  git diff --name-only "$range" >/dev/null 2>&1 || { echo "range: git diff $range failed — fix the range (bad ref, or a shallow clone: git fetch --unshallow)"; exit 2; }
  for c in intent-layout adr-numbering adr-refs skill-frontmatter skill-links template-gate-parity agents-commands; do run "$c" .; done
  echo "$ran_ok ok, $fail_count failed (range: $range)"
  lane_run "$range" || true   # trailer, not a check: same range as the gate so one paste carries both
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
  else echo "witness FAIL: $name @$label expected $want, got $v${why:+ — $why}"; wfail=$((wfail+1)); fi
}
have_sha() { git cat-file -e "$1^{commit}" 2>/dev/null || { echo "witness FAIL: sha $1 not in history (git fetch --unshallow)"; wfail=$((wfail+1)); return 1; }; }
reset_wt() { git -C "$1" checkout --quiet -- . && git -C "$1" clean -fdq; }

witness_run() {
  [ "$(git rev-parse --is-shallow-repository)" = false ] || { echo "!! shallow clone: run 'git fetch --unshallow' first"; exit 2; }
  BASE=$(mktemp -d "${TMPDIR:-/tmp}/validate.XXXXXX"); trap cleanup EXIT
  have_sha 1b41a31 || exit 2

  # sha witnesses — static
  worktree 1b41a31; local w=$W
  expect FAIL 1b41a31 adr-refs "$w"

  # mutation witnesses — one-line mutations on a worktree copy of HEAD, reset between rows
  worktree HEAD; local m=$W
  # #45: the whole gate under a hook-exported GIT_DIR in a linked worktree (end-to-end, not one check)
  gitdir_row() {  # gitdir_row <ok|FAIL> <label>
    local got=FAIL; wn=$((wn+1))
    (cd "$m" && GIT_DIR=$(git rev-parse --git-dir) bash tests/validate.sh HEAD..HEAD >/dev/null 2>&1) && got=ok
    if [ "$got" = "$1" ]; then echo "witness ok: gate @$2 expected $1"
    else echo "witness FAIL: gate @$2 expected $1, got $got"; wfail=$((wfail+1)); fi
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
    else echo "witness FAIL: summary @$2 expected $1, got summary=$sum vs ok-lines=$lines"; wfail=$((wfail+1)); fi
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
  [[ $why == *'enable symlinks'* ]] || { echo "witness FAIL: skill-links @mutation(link checked out as a text file) expected the message to name the fix (enable symlinks), got: $why"; wfail=$((wfail+1)); }
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
  # agents-commands: rewrite the ## Commands block with every --list name (control: ok), then all but one (FAIL)
  commands_block() { awk '/^## Commands/{c=1;next} /^## /{c=0} !c' "$m/AGENTS.md"; echo; echo '## Commands'; echo; list_checks | sed "$1" | sed 's/.*/`&`/' | tr '\n' ' '; echo; }
  commands_block '' > "$m/AGENTS.tmp" && mv "$m/AGENTS.tmp" "$m/AGENTS.md"
  expect ok 'mutation(full block)' agents-commands "$m"; reset_wt "$m"
  commands_block 1d > "$m/AGENTS.tmp" && mv "$m/AGENTS.tmp" "$m/AGENTS.md"
  expect FAIL 'mutation(one name deleted)' agents-commands "$m"; reset_wt "$m"

  # merge hold (ADR 0005) — one row per held path plus every known evasion; a missed hold lets a PR merge its own gate
  flag_expect() {  # flag_expect <yes|no> <label> <root> <range>
    local got=no; wn=$((wn+1)); lane_of "$3" "$4"; [ -z "$held" ] || got=yes
    if [ "$got" = "$1" ]; then echo "witness ok: flagged @$2 expected $1${held:+ (${held% })}"
    else echo "witness FAIL: flagged @$2 expected $1, got $got"; wfail=$((wfail+1)); fi
  }
  local l=$m; lane_reset() { git -C "$1" reset -q --hard && git -C "$1" clean -fdq; }; lane_reset "$l"
  wn=$((wn+1)); if lane_of "$l" HEAD..HEAD; [ $? = 2 ]; then echo "witness ok: lane @empty range expected rc 2 ($lane_why)"
  else echo "witness FAIL: lane @empty range expected rc 2"; wfail=$((wfail+1)); fi
  printf 'x\n' >> "$l/handoffs/build-stage-handoff.md";              flag_expect no 'mutation(handoffs/, not held)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/tests/validate.sh";                              flag_expect yes 'mutation(tests/validate.sh held)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/.github/workflows/gate.yml";                     flag_expect yes 'mutation(.github/workflows/ held)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/.githooks/pre-push";                             flag_expect yes 'mutation(.githooks/ held)' "$l" HEAD; lane_reset "$l"
  git -C "$l" mv .githooks/pre-push pre-push;                          flag_expect yes 'mutation(rename a held file out — read as its delete)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/plugin/templates/new-project/files/tests/validate.sh"; flag_expect yes 'mutation(template tests/validate.sh held — #128)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/plugin/templates/new-project/files/.github/workflows/gate.yml"; flag_expect yes 'mutation(template .github/workflows/ held — #128)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' > "$l/.github/workflows/a\"b.yml";                      flag_expect yes 'mutation(untracked quoted workflow filename — #78)' "$l" HEAD
  git -C "$l" add '.github/workflows/a"b.yml';                         flag_expect yes 'mutation(staged quoted workflow filename — #78)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' >> "$l/.github/workflows/gate.yml"; git -C "$l" add -A; git -C "$l" update-index --add --cacheinfo "100644,$(git -C "$l" hash-object -w --stdin <<<x),$(printf 'handoffs/a\377b.md')"
  git -C "$l" -c user.name=w -c user.email=w@w -c commit.gpgsign=false commit --no-verify -qm w || exit 2; flag_expect yes 'mutation(invalid-UTF-8 name + held change — #78)' "$l" HEAD~1..HEAD; git -C "$l" reset -q --hard HEAD~1
  printf 'x\n' >> "$l/.github/workflows/gate.yml"; git init -q "$l/handoffs/sub"; flag_expect yes 'mutation(untracked nested repo + held change — #78)' "$l" HEAD; rm -rf "$l/handoffs/sub"; lane_reset "$l"

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
    else echo "witness FAIL: lane-base @$2 expected $1, got $got — $out"; wfail=$((wfail+1)); fi
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
    else echo "witness FAIL: new-project @$2 expected $1, got $got — $(tail -3 <<<"$out" | tr '\n' ' ')"; wfail=$((wfail+1)); fi
  }
  local np=$BASE/np; mkdir -p "$np"; git init -q "$np"
  np_expect ok   'scaffold into an empty dir' "bash '$m/plugin/templates/new-project/scaffold.sh' . --owner demo --name demo"
  np_expect ok   'every {{TOKEN}} substituted' "! grep -rIn --exclude-dir=.git '{{' . | grep -v '\${{ github\.'"
  np_expect ok   'scaffolded gate.yml never passes --fast (ADR 0007: CI is the proof of the suite)' '! grep -qF -- --fast .github/workflows/gate.yml'
  # dispatch's old-script test reads the usage line, never the file (a witness label may name a flag): the scaffolded gate is new
  np_expect ok   'scaffolded gate reads as new (usage line lists --fast and --deadline)' "(set +o pipefail; bash tests/validate.sh --probe-usage 2>&1 | grep -q -- '--fast') && (set +o pipefail; bash tests/validate.sh --probe-usage 2>&1 | grep -q -- '--deadline')"
  # F2 in the scaffolded gate: the summary counts the ok: lines that ran
  np_expect ok   'scaffolded gate passes, summary counts what ran' 'out=$(bash tests/validate.sh) && [ "$(grep -c "^ok: " <<<"$out")" = "$(sed -nE "s/^([0-9]+) ok, [0-9]+ failed.*/\1/p" <<<"$out")" ]'
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

  # #176: QC reads the hold with origin/<base>'s script, never the PR's own (ADR 0007). Scratch repo: main = this
  # script; branch t1-x rewrites it to print `flagged: no`. The first row shows the attack works on the PR's own script.
  g=$BASE/hold; git init -q "$g"; gc symbolic-ref HEAD refs/heads/main; mkdir "$g/tests"; cp "$m/tests/validate.sh" "$g/tests/"
  gc add -A; gc commit -qm base; gc update-ref refs/remotes/origin/main HEAD
  gc checkout -qb t1-x; printf 'echo "flagged: no"\n' >"$g/tests/validate.sh"; gc commit -qam 'clear my own hold'
  hold_expect() {  # hold_expect <yes|no> <label> <command run in $g>
    local got=no; wn=$((wn+1)); (cd "$g" && eval "$3") 2>/dev/null | grep -q '^flagged: yes' && got=yes
    if [ "$got" = "$1" ]; then echo "witness ok: base-lane @$2 expected flagged: $1"
    else echo "witness FAIL: base-lane @$2 expected flagged: $1, got $got"; wfail=$((wfail+1)); fi
  }
  hold_expect no  "the PR's own script prints its own flagged: no" 'bash tests/validate.sh --lane origin/main..HEAD'
  hold_expect yes "origin/main's script, piped, on the same branch" 'git show origin/main:tests/validate.sh | bash -s -- --lane origin/main..HEAD'
  # this repo's root script has no --fast or --deadline: dispatch's usage-line test must read it as old
  wn=$((wn+1)); if (set +o pipefail; cd "$m" && bash tests/validate.sh --probe-usage 2>&1 | grep -q -- '--fast'); then echo "witness FAIL: old-script @this repo's root script expected old, got new"; wfail=$((wfail+1))
  else echo "witness ok: old-script @this repo's root script expected old (no --fast in its usage line)"; fi
  # a range is never an option: `git diff --output=<file>` would write a file (both lane_of copies refuse it)
  wn=$((wn+1)); out=$(cd "$m" && bash tests/validate.sh --lane --output="$BASE/pwned" 2>&1)
  if [ $? = 2 ] && grep -q 'usage:' <<<"$out" && [ ! -e "$BASE/pwned" ]; then echo "witness ok: lane @--lane --output=<file> expected usage, exit 2, no file written"
  else echo "witness FAIL: lane @--lane --output=<file> expected usage, exit 2, no file written — $out"; wfail=$((wfail+1)); fi
  # a range git cannot read is an error, never a silent pass (sync-rule caught it until #181)
  wn=$((wn+1)); out=$(cd "$m" && bash tests/validate.sh nope..HEAD 2>&1)
  if [ $? = 2 ] && grep -q '^range: git diff nope..HEAD failed' <<<"$out"; then echo "witness ok: gate @unreadable range expected exit 2"
  else echo "witness FAIL: gate @unreadable range expected exit 2 and a range: line, got: $(tail -1 <<<"$out")"; wfail=$((wfail+1)); fi
  # one review lane (ADR 0008): --lane prints the range: line and the flagged: line, no tier
  wn=$((wn+1)); out=$(cd "$m" && bash tests/validate.sh --lane HEAD~1..HEAD 2>&1)
  if [ "$(cut -d: -f1 <<<"$out" | tr '\n' ' ')" = "range flagged " ]; then echo "witness ok: lane @--lane expected range: and flagged: lines only"
  else echo "witness FAIL: lane @--lane expected range: and flagged: lines only, got: ${out//$'\n'/ | }"; wfail=$((wfail+1)); fi
  # the template's witness copies its own file, not the cwd's tests/validate.sh: run in place from this repo, it passes
  np_expect ok   'the template --witness run in place from this repo passes' "cd '$m' && bash plugin/templates/new-project/files/tests/validate.sh --witness | tail -1 | grep -qE '^[1-9][0-9]* witnesses, 0 unexpected$'"

  echo "$wn witnesses, $wfail unexpected"
  exit $((wfail > 0))
}

case ${1:-} in
  --list) list_checks; exit 0 ;;
  --witness) witness_run ;;
  --lane) lane_run "${2:-}"; exit $? ;;
  --*) echo "usage: $0 [<range>|--list|--witness|--lane [<range>]]" >&2; exit 2 ;;
esac

default_run "${1:-}"
exit $fail
