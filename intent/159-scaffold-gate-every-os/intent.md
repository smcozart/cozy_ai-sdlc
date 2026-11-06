# Intent: a scaffolded project's gate is LF, executable and witness-honest on macOS, Linux and Windows, proven in CI

**Issue:** #159 · **Status:** draft · **Type:** system-change

**Touches:** `["plugin/templates/new-project/files/.gitattributes", ".gitattributes", "plugin/templates/new-project/files/tests/validate.sh", "tests/validate.sh", "plugin/skills/new-project/SKILL.md", ".github/workflows/gate.yml", "plugin/.claude-plugin/plugin.json"]`

## Problem

Found on Windows 11 + Git Bash (`core.autocrlf=true`, `core.symlinks=false`), ai-sdlc 1.8.1. In a freshly scaffolded project, `bash tests/validate.sh --witness` ends `34 witnesses, 1 unexpected` (`app-tests @symlink under intent/`: Git Bash `ln -s` copies). A clone checks out CRLF (no `.gitattributes`). The gate is staged `100644` (`chmod +x` does nothing for git when `core.filemode=false`). The witness summary prints a flag, not a count. CI runs on Linux only.

## Desired outcome

One code path on every OS: a scaffolded project checks out LF and keeps `tests/validate.sh` at `100755`; its gate and `--witness` pass; a row the filesystem cannot express prints `witness skipped: <row> — <why>` and is not counted as a witness; `M unexpected` counts the failed rows. A `template` CI job runs scaffold, commit, clone, then the gate, `--witness` and a no-CRLF assertion on `ubuntu-latest`, `macos-latest` and `windows-latest`.

## Scope

- `.gitattributes` (`* text=auto eol=lf`) in the template and at this repo's root.
- Template witness: probe whether `ln -s` makes a symlink; skip the symlink row honestly when it does not; count failures. Root witness: count failures.
- `new-project` Move 3: `git add --chmod=+x` for a written `tests/validate.sh`.
- `gate.yml`: the `template` matrix job. `gate` stays as it is.
- `plugin.json` version.

## Non-goals

- This repo's own Windows witness rows (#164).
- Making `template` a required check (branch protection, a human decision).
- Appending to an existing repo's `.gitattributes` (scaffold skips an existing one, as for every non-marker file).

## Acceptance criteria

- Windows (Git Bash): scaffold into a fresh repo, commit, clone: `git ls-files --eol` shows no `w/crlf`; `git ls-files -s tests/validate.sh` is `100755`; `bash tests/validate.sh` exits 0; `--witness` prints `witness skipped: app-tests @symlink under intent/ …` and ends `N witnesses, 0 unexpected`, exit 0.
- `template` job green on all three OSes; on Linux and macOS the symlink row runs (`witness ok: app-tests @symlink under intent/ expected run`).
- Fail-first: the template witness on Windows before the change prints the FAIL row; after, the skip line.
- `bash tests/validate.sh origin/main..HEAD <body>` exits 0 with `flagged: yes`; a named human merges.

## System-intent alignment

The harness is tool- and host-agnostic; proving the consumer's gate on every OS keeps that a fact, not a claim.
