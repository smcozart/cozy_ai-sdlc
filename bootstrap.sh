#!/usr/bin/env bash
# Bootstrap the engineering harness on a new machine or after a laptop dies.
# Idempotent — safe to re-run. Requires: git. Optional: gh, claude, pi, herdr.
set -uo pipefail
cd "$(dirname "$0")"

fail=0
have() { command -v "$1" >/dev/null 2>&1; }

echo "==> 1/5 Matt Pocock skills"
# Claude Code: a project-scope plugin named in .claude/settings.json (step 3).
# pi + editable installs: copy full skill dirs (SKILL.md + agents/ subdirs) from
# upstream, recorded by skills-lock.json. No hash check — the lock hash is not a
# plain file sha; provenance = upstream HEAD sha printed below.
if have python3 && [ -f skills-lock.json ]; then
  rm -rf /tmp/skills-upstream
  SRC=mattpocock/skills
  git clone --quiet --depth 1 "https://github.com/$SRC" /tmp/skills-upstream \
    && UP=$(git -C /tmp/skills-upstream rev-parse --short HEAD) \
    || { echo "  !! upstream clone failed"; fail=1; }
  if [ -n "${UP:-}" ]; then
    python3 - skills-lock.json <<'PY' | while IFS=$'\t' read -r name path; do
import json,sys
for name,s in json.load(open(sys.argv[1]))["skills"].items():
    print(f"{name}\t{s['skillPath'].rsplit('/SKILL.md',1)[0]}")
PY
      rm -rf ".agents/skills/$name"
      cp -R "/tmp/skills-upstream/$path" ".agents/skills/$name"
      echo "  ok: $name (pi)"
    done
    echo "  provenance: $SRC @ $UP"
    rm -rf /tmp/skills-upstream
  fi
fi

echo "==> 2/5 Vendored skills"
[ -f .agents/skills/ponytail/SKILL.md ] && echo "  ok: ponytail (tracked in repo)" || { echo "  !! ponytail missing"; fail=1; }

echo "==> 3/5 Harness registration"
if have gh && gh auth status >/dev/null 2>&1; then echo "  ok: gh authenticated"
else echo "  !! run: gh auth login"; fail=1; fi
# Claude Code tools: what .claude/settings.json names, at project scope, from
# the cozysuite catalog (github.com/smcozart/cozysuite). Never user scope.
if have claude && have python3 && [ -f .claude/settings.json ]; then
  claude plugin marketplace add smcozart/cozysuite --scope project >/dev/null 2>&1 || true
  claude plugin marketplace update cozysuite >/dev/null 2>&1 || true
  for id in $(python3 -c 'import json; print(" ".join(k for k, v in json.load(open(".claude/settings.json")).get("enabledPlugins", {}).items() if v))'); do
    claude plugin install "$id" --scope project >/dev/null 2>&1 \
      && echo "  ok: $id (project scope)" || { echo "  !! $id install failed"; fail=1; }
  done
elif have claude; then
  echo "  -- no .claude/settings.json: set up tools per the cozysuite README (\"Set up a project\")"
else
  echo "  -- claude not installed, skipping plugin install"
fi

echo "==> 4/5 Git hooks (local guardrail)"
if [ "$(git config --local --get core.hooksPath 2>/dev/null)" = ".githooks" ]; then
  echo "  ok: already configured (hooks: .githooks)"
else
  gp=$(git config --global --get core.hooksPath 2>/dev/null || true)
  [ -n "$gp" ] && echo "  -- note: global core.hooksPath=$gp left intact; the local setting overrides it for this repo only"
  if git config core.hooksPath .githooks; then echo "  ok: core.hooksPath -> .githooks (local)"
  else echo "  !! git config core.hooksPath failed"; fail=1; fi
fi

echo "==> 5/5 Optional tooling"
have herdr && echo "  ok: herdr" || echo "  -- herdr not installed (only needed for parallel orchestrated builds)"
[ -f .env ] || [ ! -f .env.example ] || echo "  -- note: cp .env.example .env and fill in secrets (never committed)"

if [ "$fail" -eq 1 ]; then echo; echo "DONE with warnings — fix the !! lines above."; else echo; echo "DONE — harness restored."; fi
exit $fail