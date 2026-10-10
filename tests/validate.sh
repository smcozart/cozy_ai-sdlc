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

FO=plugin/skills/factory-orchestrator/SKILL.md
DOC=docs/engineering-workflow.md
SK=plugin/skills/engineering-workflow/SKILL.md
CHECKS="sync-rule stage-parity intent-layout adr-numbering adr-refs hooks-json skill-frontmatter skill-copies agents-commands t1-trust-wording t1-log-clobber t1-spawn-session t3-label-drift t3-precedence pr-adr-line"

fail=0; why=""
list_checks() { printf '%s\n' $CHECKS; }

# ---------- lane classifier (Deploy: review effort follows the lane; ADR 0003) ----------
# A classifier, not a check: it prints one `lane:` line and one `flagged:` line to paste beside the
# gate run. It is an ALLOW-list — only paths in LANE_LIGHT may take a reduced budget; everything else,
# including every path this repo has not grown yet, is T2. Renames are read as delete+add (--no-renames)
# so a move out of a protected path is the delete it is; quotePath is off so non-ASCII paths still match.
# Instruction files (LANE_NEVER, any case) are T2 wherever they sit; deletes, binaries and symlinks are T2
# (a symlink is never followed — its target may sit outside the repo). The agent still
# confirms "earns no ADR" and "not speculative", and may only ESCALATE the printed lane.
# Consumers extend LANE_LIGHT (safe by omission) and LANE_FLOOR_T1 (light files a session acts on).
# LANE_HOLD is the merge hold list (ADR 0005): the files that enforce the gate. `flagged: yes` = a human merges.
LANE_LIGHT='^(handoffs/|docs/training/|STATUS\.md$|LICENSE$)'
LANE_FLOOR_T1='^(STATUS\.md$|docs/training/|handoffs/pickup-handoff\.md$)'   # README.md anywhere is LANE_NEVER (T2), never a floor entry
LANE_NEVER='(^|/)(CLAUDE|AGENTS|GEMINI|COPILOT|README)\.md$|(^|/)\.(cursorrules|mcp\.json|gitmodules)$'
LANE_HOLD='^(tests/validate\.sh$|\.github/workflows/|\.githooks/)'
LANE_MAX_FILES=2; LANE_MAX_LINES=60
lane_of() {  # lane_of <root> <range> -> sets lane (T0|T1|T2|none), lane_why and held; rc 2 when there is no lane
  local r=$1 range=$2 st files n never outside del ns lines bin untracked="" o links
  held=""
  st=$(git -C "$r" -c core.quotePath=off diff --no-renames --name-status "$range" 2>/dev/null) || { lane=none; lane_why="git diff $range failed — fix the range"; return 2; }
  # the dirty tree includes untracked files; `git diff HEAD` does not list them, so a new file would otherwise vanish from the lane
  [ "$range" != HEAD ] || untracked=$(git -C "$r" -c core.quotePath=off ls-files --others --exclude-standard)
  [ -n "$st$untracked" ] || { lane=none; lane_why="empty range — fix the range"; return 2; }
  files=$({ [ -z "$st" ] || cut -f2- <<<"$st"; [ -z "$untracked" ] || printf '%s\n' "$untracked"; }); n=$(grep -c . <<<"$files")
  held=$(grep -E "$LANE_HOLD" <<<"$files" | tr '\n' ' ')
  del=$(awk -F'\t' '$1 ~ /^D/ {print $2}' <<<"$st" | tr '\n' ' ')
  never=$(grep -iE "$LANE_NEVER" <<<"$files" | tr '\n' ' ')
  links=$(git -C "$r" -c core.quotePath=off diff --no-renames --raw "$range" | awk -F'\t' '$1 ~ / 120000 |^:120000 / {print $2}' | tr '\n' ' ')
  outside=$(grep -vE "$LANE_LIGHT" <<<"$files" | tr '\n' ' ')
  ns=$(git -C "$r" -c core.quotePath=off diff --no-renames --numstat "$range" | awk -F'\t' '$1=="-"||$2=="-"{b=1} {a+=$1; d+=$2} END{print a+d+0, b+0}')
  lines=${ns%% *}; bin=${ns##* }
  while IFS= read -r o; do [ -n "$o" ] || continue   # untracked: count lines ourselves, NUL byte = binary; never follow a symlink
    if [ -L "$r/$o" ]; then links="$links$o "
    elif [ "$(head -c 8000 "$r/$o" | tr -d '\000' | wc -c)" -ne "$(head -c 8000 "$r/$o" | wc -c)" ]; then bin=1; else lines=$((lines + $(wc -l <"$r/$o"))); fi
  done <<<"$untracked"
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
lane_run() {  # lane_run [<range>] -> prints the lane and flagged lines with resolved shas; exit 0 on a lane, 2 on none
  local range=${1:-} a b m base="" shown partial=""
  # dirty = tracked changes OR untracked files; a new file alone must not fall through to HEAD~1..HEAD
  if [ -z "$range" ]; then if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then range=HEAD; else range=HEAD~1..HEAD; fi; fi
  lane_of . "$range"
  if [ "$range" = HEAD ]; then shown="dirty tree vs $(git rev-parse --short HEAD)"
  elif [[ $range == *..* ]]; then
    a=$(git rev-parse --short "${range%%..*}" 2>/dev/null); b=$(git rev-parse --short "${range##*..}" 2>/dev/null); shown="$a..$b"
    for m in origin/main main; do git rev-parse -q --verify "$m^{commit}" >/dev/null 2>&1 && { base=$(git merge-base "$m" "${range##*..}" 2>/dev/null); break; }; done
    # a partial range hides files: the close needs the ticket's full range, i.e. merge-base(main, tip)..tip
    if [ -n "$base" ] && [ "$(git rev-parse "${range##*..}")" != "$(git rev-parse "$m")" ] \
       && [ "$(git rev-parse "${range%%..*}" 2>/dev/null)" != "$base" ]; then partial=" — PARTIAL RANGE (base is not the merge-base with $m); not valid for a close"; fi
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
  grep -qxE "$DOC|$SK" <<<"$files" || return 0
  local n; n=$(grep -cxE "$DOC|$SK|README.md" <<<"$files")
  [ "$n" -eq 3 ] || { why="$1 touches $DOC/SKILL.md; expected 3 of {doc,SKILL.md,README.md}, found $n"; return 1; }
}

check_stage_parity() {
  local r=$1 d s m
  for f in "$DOC" "$SK" README.md; do [ -f "$r/$f" ] || { why="$f missing"; return 1; }; done
  d=$(grep -cE '^## (Plan|Design|Build|Test|Deploy|Maintain)\b' "$r/$DOC")
  s=$(grep -cE '^## (Plan|Design|Build|Test|Deploy|Maintain)\b' "$r/$SK")
  m=$(grep -cE '^(Plan|Design|Build|Test|Deploy|Maintain) (─)+►' "$r/README.md")
  [ "$d$s$m" = 666 ] || { why="expected 6 stage headings each; found doc=$d SKILL.md=$s README=$m"; return 1; }
  d=$(grep -oE '^## (Plan|Design|Build|Test|Deploy|Maintain)\b' "$r/$DOC" | grep -oE '(Plan|Design|Build|Test|Deploy|Maintain)' | sort -u | wc -l | tr -d " ")
  s=$(grep -oE '^## (Plan|Design|Build|Test|Deploy|Maintain)\b' "$r/$SK" | grep -oE '(Plan|Design|Build|Test|Deploy|Maintain)' | sort -u | wc -l | tr -d " ")
  m=$(grep -oE '^(Plan|Design|Build|Test|Deploy|Maintain) (─)+►' "$r/README.md" | grep -oE '(Plan|Design|Build|Test|Deploy|Maintain)' | sort -u | wc -l | tr -d " ")
  [ "$d$s$m" = 666 ] || { why="expected 6 distinct stage names each; found doc=$d SKILL.md=$s README=$m"; return 1; }
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

check_hooks_json() {
  local f=$1/plugin/hooks/hooks.json
  [ -f "$f" ] || { why="plugin/hooks/hooks.json missing"; return 1; }
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert list(d)==["hooks"]; [ (h["type"],h["command"]) for ev in d["hooks"].values() for m in ev for h in m["hooks"] ]' "$f" 2>/dev/null \
    || { why="plugin/hooks/hooks.json: expected sole key hooks + type/command per entry; python3 rejected it"; return 1; }
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

check_skill_copies() {
  cmp -s "$1/$FO" "$1/.agents/skills/factory-orchestrator/SKILL.md" \
    || { why="$FO and .agents/skills/factory-orchestrator/SKILL.md differ (must be byte-identical)"; return 1; }
  cmp -s "$1/$FO" "$1/.claude/skills/factory-orchestrator/SKILL.md" \
    || { why="$FO and .claude/skills/factory-orchestrator/SKILL.md differ (must be byte-identical)"; return 1; }
  cmp -s "$1/$SK" "$1/.claude/skills/engineering-workflow/SKILL.md" \
    || { why="$SK and .claude/skills/engineering-workflow/SKILL.md differ (must be byte-identical)"; return 1; }
}

check_agents_commands() {
  local r=$1 have want
  [ -f "$r/AGENTS.md" ] || { why="AGENTS.md missing"; return 1; }
  have=$(awk '/^## Commands/{c=1;next} /^## /{c=0} c' "$r/AGENTS.md" | grep -oE '`[a-z0-9-]+`' | tr -d '`' | sort -u)
  want=$(list_checks | sort -u)
  [ "$have" = "$want" ] || { why="AGENTS.md ## Commands names != --list; missing:[$(comm -13 <(echo "$have") <(echo "$want") | tr '\n' ' ')] extra:[$(comm -23 <(echo "$have") <(echo "$want") | tr '\n' ' ')]"; return 1; }
}

# ---------- regression half (#8 corpus): check_<name> <file>, never stdin ----------
# t1-trust-wording  FO  bad 7e8a195 ("skips"), da9eb33 (REFUSES)  good 4e9b547
check_t1_trust_wording() {
  grep -q 'trust dialog is SKIPPED' "$1" && ! grep -qw REFUSES "$1" \
    || { why="$1: expected 'trust dialog is SKIPPED' and no REFUSES"; return 1; }
}
# t1-log-clobber  FO  bad da9eb33  good 4e9b547
check_t1_log_clobber() {
  ! grep -qE '>log[[:space:]]' "$1" || { why="$1: bare '>log ' redirect clobbers the shared log"; return 1; }
}
# t1-spawn-session  FO  bad 7e8a195, da9eb33  good 4e9b547
check_t1_spawn_session() {
  grep -qE '^- Spawn:.*--output-format' "$1" || { why="$1: Spawn line does not capture a session id (--output-format)"; return 1; }
}
# t3-label-drift  AGENTS.md  bad 43b63dc  good 92e6a25
check_t3_label_drift() {
  grep -qF 'does NOT apply `ready-for-agent` at spec time' "$1" && ! grep -qF 'never auto-apply labels' "$1" \
    || { why="$1: expected 'does NOT apply \`ready-for-agent\` at spec time' and no 'never auto-apply labels'"; return 1; }
}
# t3-precedence  AGENTS.md  bad 43b63dc  good 92e6a25
check_t3_precedence() {
  grep -qF 'Overrides to the vendored skill:' "$1" || { why="$1: missing 'Overrides to the vendored skill:'"; return 1; }
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
fail_count=0
run() {
  verdict "$@"
  case $v in ok) echo "ok: $1" ;; *) echo "FAIL: $1 — $why"; fail=1; fail_count=$((fail_count+1)) ;; esac
}

default_run() {
  local range=${1:-} body=${2:-} skip=0
  if [ -z "$range" ]; then
    if ! git diff --quiet HEAD 2>/dev/null; then range=HEAD; else range=HEAD~1..HEAD; fi
  fi
  run sync-rule "$range"
  for c in stage-parity intent-layout adr-numbering adr-refs hooks-json skill-frontmatter skill-copies agents-commands; do run "$c" .; done
  for c in t1-trust-wording t1-log-clobber t1-spawn-session; do run "$c" "$FO"; done
  for c in t3-label-drift t3-precedence; do run "$c" AGENTS.md; done
  if [ -n "$body" ]; then run pr-adr-line "$body"; else echo "skipped: pr-adr-line — no PR body file given (CI passes one)"; skip=1; fi
  local n; n=$(list_checks | wc -l | tr -d ' ')
  echo "$((n - fail_count - skip)) ok, $fail_count failed (range: $range)"
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
sha_row() { showfile "$2" "$4"; expect "$1" "$2" "$3" "$T"; }  # sha_row <ok|FAIL> <sha> <check> <path>
reset_wt() { git -C "$1" checkout --quiet -- . && git -C "$1" clean -fdq; }

witness_run() {
  [ "$(git rev-parse --is-shallow-repository)" = false ] || { echo "!! shallow clone: run 'git fetch --unshallow' first"; exit 2; }
  BASE=$(mktemp -d "${TMPDIR:-/tmp}/validate.XXXXXX"); trap cleanup EXIT
  for s in a6519a9 571afe4 1b41a31 7e8a195 da9eb33 4e9b547 43b63dc 92e6a25; do have_sha "$s" || exit 2; done

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
  (cd "$m" && python3 -c "p='intent/9-test-stage/intent.md';s=open(p).read().replace('#9','#8');open(p,'w').write(s)")
  expect FAIL mutation intent-layout "$m"; reset_wt "$m"
  : >"$m/docs/adr/0009-x.md"
  expect FAIL mutation adr-numbering "$m"; reset_wt "$m"
  python3 -c "import sys;p=sys.argv[1];s=open(p).read();i=s.rstrip().rfind('}');open(p,'w').write(s[:i]+','+s[i:])" "$m/plugin/hooks/hooks.json"
  expect FAIL mutation hooks-json "$m"; reset_wt "$m"
  (cd "$m" && grep -v '^name:' $FO > t && mv t $FO)
  expect FAIL mutation skill-frontmatter "$m"; reset_wt "$m"
  echo x >> "$m/.agents/skills/factory-orchestrator/SKILL.md"
  expect FAIL mutation skill-copies "$m"; reset_wt "$m"
  echo x >> "$m/.claude/skills/factory-orchestrator/SKILL.md"
  expect FAIL 'mutation(.claude factory copy)' skill-copies "$m"; reset_wt "$m"
  grep -v '^## Maintain' "$m/$DOC" > "$m/t" && mv "$m/t" "$m/$DOC"
  expect FAIL 'mutation(-## Maintain)' stage-parity "$m"; reset_wt "$m"
  grep -v '^## Maintain' "$m/$SK" > "$m/t" && mv "$m/t" "$m/$SK"
  expect FAIL 'mutation(-## Maintain SKILL)' stage-parity "$m"; reset_wt "$m"
  grep -v '^Maintain ' "$m/README.md" > "$m/t" && mv "$m/t" "$m/README.md"
  expect FAIL 'mutation(-Maintain README)' stage-parity "$m"; reset_wt "$m"
  sed -i.bak 's/^## Maintain/## Test/' "$m/$DOC"
  expect FAIL 'mutation(## Maintain→## Test)' stage-parity "$m"; reset_wt "$m"
  sed -i.bak 's/^## Maintain/## Test/' "$m/$SK"
  expect FAIL 'mutation(## Maintain→## Test SKILL)' stage-parity "$m"; reset_wt "$m"
  sed -i.bak 's/^Maintain ─►/Test ──►/' "$m/README.md"
  expect FAIL 'mutation(Maintain─►→Test README)' stage-parity "$m"; reset_wt "$m"
  # agents-commands: rewrite the ## Commands block with every --list name (control: ok), then all but one (FAIL)
  commands_block() { awk '/^## Commands/{c=1;next} /^## /{c=0} !c' "$m/AGENTS.md"; echo; echo '## Commands'; echo; list_checks | sed "$1" | sed 's/.*/`&`/' | tr '\n' ' '; echo; }
  commands_block '' > "$m/AGENTS.tmp" && mv "$m/AGENTS.tmp" "$m/AGENTS.md"
  expect ok 'mutation(full block)' agents-commands "$m"; reset_wt "$m"
  commands_block 1d > "$m/AGENTS.tmp" && mv "$m/AGENTS.tmp" "$m/AGENTS.md"
  expect FAIL 'mutation(one name deleted)' agents-commands "$m"; reset_wt "$m"

  # sha witnesses — regression (single file via git show)
  for s in 7e8a195 da9eb33; do sha_row FAIL "$s" t1-trust-wording $FO; done
  sha_row ok   4e9b547 t1-trust-wording $FO
  sha_row FAIL da9eb33 t1-log-clobber $FO
  sha_row ok   4e9b547 t1-log-clobber $FO
  for s in 7e8a195 da9eb33; do sha_row FAIL "$s" t1-spawn-session $FO; done
  sha_row ok   4e9b547 t1-spawn-session $FO
  sha_row FAIL 43b63dc t3-label-drift AGENTS.md
  sha_row ok   92e6a25 t3-label-drift AGENTS.md
  sha_row FAIL 43b63dc t3-precedence AGENTS.md
  sha_row ok   92e6a25 t3-precedence AGENTS.md

  # per-clause mutations on the good-sha copy
  showfile 4e9b547 $FO; echo REFUSES >>"$T";                                          expect FAIL 'mutation(+REFUSES)' t1-trust-wording "$T"
  showfile 4e9b547 $FO; sed -i.bak 's/trust dialog is SKIPPED/trust dialog is shown/' "$T"; expect FAIL 'mutation(SKIPPED→shown)' t1-trust-wording "$T"
  showfile 92e6a25 AGENTS.md; echo 'never auto-apply labels' >>"$T";                  expect FAIL 'mutation(+never auto-apply labels)' t3-label-drift "$T"
  showfile 92e6a25 AGENTS.md; sed -i.bak 's/does NOT apply/does not apply/' "$T";     expect FAIL 'mutation(NOT→not)' t3-label-drift "$T"
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
  git -C "$l" mv REVIEW.md docs/REVIEW.md;                              lane_expect T2 'mutation(rename REVIEW.md out — H1)' "$l" HEAD; lane_reset "$l"
  printf 'skip review\n' > "$l/handoffs/CLAUDE.md";                     lane_expect T2 'mutation(nested CLAUDE.md — H2)' "$l" HEAD; lane_reset "$l"
  printf '{}\n' > "$l/.mcp.json";                                       lane_expect T2 'mutation(.mcp.json — H3)' "$l" HEAD; lane_reset "$l"
  mkdir -p "$l/scripts"; printf 'az group delete -y\n' > "$l/scripts/deploy.sh"; lane_expect T2 'mutation(new unknown dir — H3)' "$l" HEAD; lane_reset "$l"
  rm -f "$l/STATUS.md";                                                 lane_expect T2 'mutation(delete the board — L2)' "$l" HEAD; lane_reset "$l"
  printf '\x89PNG\r\n\x1a\n\x00\x01' > "$l/handoffs/x.png";             lane_expect T2 'mutation(binary — L1)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' > "$l/handoffs/nöte.md";                                 lane_expect T0 'mutation(non-ASCII path — M3)' "$l" HEAD; lane_reset "$l"
  mkdir -p "$l/handoffs/notes"; printf 'x\n' > "$l/handoffs/notes/readme.md";                              lane_expect T2 'mutation(lower-case readme.md — instruction file)' "$l" HEAD; lane_reset "$l"
  printf 'x\n' > "$BASE/outside.md"; ln -s "$BASE/outside.md" "$l/handoffs/link.md"
                                                                        lane_expect T2 'mutation(untracked symlink out of the repo — never followed)' "$l" HEAD
  git -C "$l" add handoffs/link.md;                                     lane_expect T2 'mutation(staged symlink — mode 120000)' "$l" HEAD; lane_reset "$l"

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
