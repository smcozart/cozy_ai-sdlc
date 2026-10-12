#!/usr/bin/env bash
# The new-project file step: copy files/** into <target-dir>, never overwriting.
#
#   scaffold.sh <target-dir> --owner <o> [--name <n>] [--base <branch>]
#
# Substitutes {{OWNER}} {{NAME}} {{BASE}} {{PLUGIN_VERSION}} {{DATE}}; keeps each template's
# executable bit; prints `wrote:`, `appended:` or `skip: <path>` per file. No GitHub, no commit.
# AGENTS.md, CLAUDE.md and .gitignore go between start/end markers: appended to an existing file
# that lacks the marker, skipped when it is there. The policy ADR takes the next free number.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
usage() { echo "usage: $0 <target-dir> --owner <o> [--name <n>] [--base <branch>]" >&2; exit 2; }
[ $# -ge 1 ] || usage
target=$1; shift; owner=""; name=""; base=main
while [ $# -gt 0 ]; do
  case $1 in
    --owner) [ $# -ge 2 ] || usage; owner=$2; shift 2 ;;
    --name)  [ $# -ge 2 ] || usage; name=$2; shift 2 ;;
    --base)  [ $# -ge 2 ] || usage; base=$2; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$owner" ] || usage
name=${name:-$(basename "$(cd "$target" 2>/dev/null && pwd || echo "$target")")}
# values land in sed and in files; checked before anything is created
for v in "$owner" "$name"; do
  [[ $v =~ ^[A-Za-z0-9._-]+$ ]] || { echo "invalid owner/name: $v (use --owner/--name with A-Z a-z 0-9 . _ -)" >&2; exit 2; }
done
[[ $base =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "invalid base: $base (A-Z a-z 0-9 . _ / -)" >&2; exit 2; }
for f in AGENTS.md CLAUDE.md; do [ ! -L "$target/$f" ] || { echo "$f is a symlink — not supported" >&2; exit 2; }; done
mkdir -p "$target"; target=$(cd "$target" && pwd)
version=$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$here/../../.claude-plugin/plugin.json")
[ -n "$version" ] || { echo "no version in plugin.json" >&2; exit 2; }
today=$(date +%Y-%m-%d)
fill() { sed -e "s|{{OWNER}}|$owner|g" -e "s|{{NAME}}|$name|g" -e "s|{{BASE}}|$base|g" -e "s|{{PLUGIN_VERSION}}|$version|g" -e "s|{{DATE}}|$today|g" "$1"; }

cd "$here/files"
find . -type f | sed 's|^\./||' | sort | while IFS= read -r f; do
  d=$f; c=""
  case $f in
    AGENTS.md|CLAUDE.md) c='<!-- engineering-workflow:%s -->' ;;
    .gitignore)          c='# engineering-workflow:%s' ;;
    docs/adr/0001-adopt-engineering-workflow.md)
      if ls "$target"/docs/adr/*-adopt-engineering-workflow.md >/dev/null 2>&1; then echo "skip: $f"; continue; fi
      n=$(ls "$target/docs/adr" 2>/dev/null | sed -nE 's/^([0-9]+)-.*/\1/p' | sort -n | tail -1 || true)   # no docs/adr yet: 0001
      d=docs/adr/$(printf %04d $((10#${n:-0} + 1)))-adopt-engineering-workflow.md ;;
  esac
  # -L: never write through a symlink (a dangling one is not -e and would land outside the target)
  if [ -L "$target/$d" ]; then echo "skip: $d"; continue; fi
  if [ -n "$c" ]; then
    if [ -e "$target/$d" ] && grep -qF "$(printf "$c" start)" "$target/$d"; then echo "skip: $d"; continue; fi
    verb=wrote; [ -e "$target/$d" ] && verb=appended
    [ ! -s "$target/$d" ] || [ -z "$(tail -c1 "$target/$d")" ] || echo >>"$target/$d"   # the marker starts its own line
    { printf "$c\n" start; fill "$f"; printf "$c\n" end; } >>"$target/$d"
    echo "$verb: $d"; continue
  fi
  if [ -e "$target/$d" ]; then echo "skip: $d"; continue; fi
  mkdir -p "$(dirname "$target/$d")"
  fill "$f" >"$target/$d"
  [ ! -x "$f" ] || chmod +x "$target/$d"
  echo "wrote: $d"
done
