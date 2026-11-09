#!/usr/bin/env python3
"""Deterministic backstop for the merge hold (ADR 0007). Lightly measured.

`record` (UserPromptSubmit) keeps the developer's latest message per session.
`check` (PreToolUse on `gh pr merge`) refuses the merge of a held PR unless that
message came after the PR's newest commit, is not a refusal and names no other PR.

Held = a hold label, or a changed path on LANE_HOLD in tests/validate.sh. Anything
else passes untouched. A hook failure never blocks work: it warns and exits 0.
"""
import json
import re
import shlex
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HOLD_LABELS = {"flagged-risk", "ready-for-human"}
VALUE_FLAGS = {"--body-file", "-F", "--body", "-b", "--subject", "-t", "--match-head-commit",
               "--author-email", "-A", "--repo", "-R"}
# ponytail: a keyword read of "no"; a refusal phrased any other way passes, the skill's reading of the answer covers it
REFUSAL = re.compile(r"^\W*(no|nope|don'?t|do not|wait|hold|not yet|stop|cancel)\b", re.I)
NAMED_PR = re.compile(r"(?:#|\bpr\s*#?|\bmerge\s+#?|/pull/)(\d+)", re.I)
NOT_THE_DEVELOPER = ("<task-notification", "<teammate-message", "<cross-session-message")
KEEP_SESSIONS = 20


def git(cwd, *args):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8", timeout=10)
    return r.stdout.strip() if r.returncode == 0 else None


def hold_pattern(cwd):
    root = git(cwd, "rev-parse", "--show-toplevel")
    gate = Path(root or ".", "tests", "validate.sh")
    if not root or not gate.is_file():
        return None
    m = re.search(r"^LANE_HOLD='(.*)'\s*$", gate.read_text(encoding="utf-8"), re.M)
    return re.compile(m[1]) if m else None


def store_path(cwd):
    common = git(cwd, "rev-parse", "--git-common-dir")
    return Path(cwd, common, "ai-sdlc-developer-messages.json") if common else None


def load(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def record(data):
    prompt, cwd = data.get("prompt") or "", data.get("cwd") or "."
    if not prompt.strip() or prompt.lstrip().startswith(NOT_THE_DEVELOPER) or hold_pattern(cwd) is None:
        return
    path = store_path(cwd)
    messages = load(path)
    messages[data["session_id"]] = {"ts": time.time(), "prompt": prompt}
    newest = sorted(messages.items(), key=lambda kv: kv[1]["ts"])[-KEEP_SESSIONS:]
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(dict(newest)), encoding="utf-8")
    tmp.replace(path)


def parse_merges(command):
    """Every `gh pr merge` in a shell command, as (pr-or-None, repo-or-None)."""
    found = []
    for segment in re.split(r"&&|\|\||[;|\n]", command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            continue
        for i in range(len(tokens) - 2):
            if tokens[i:i + 3] != ["gh", "pr", "merge"]:
                continue
            pr = repo = None
            rest = iter(tokens[i + 3:])
            for tok in rest:
                flag, eq, val = tok.partition("=")
                if flag in VALUE_FLAGS:
                    val = val if eq else next(rest, None)
                    if flag in ("--repo", "-R"):
                        repo = val
                elif not tok.startswith("-") and pr is None:
                    pr = tok
            found.append((pr, repo))
    return found


def gh_view(pr, repo, cwd):
    args = ["gh", "pr", "view"] + ([pr] if pr else []) + (["-R", repo] if repo else [])
    args += ["--json", "number,files,labels,commits"]
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", timeout=30)
    if r.returncode != 0:
        raise RuntimeError(f"gh pr view failed: {r.stderr.strip()[:200]}")
    return json.loads(r.stdout)


def is_held(view, pattern):
    if HOLD_LABELS & {label["name"] for label in view.get("labels", [])}:
        return True
    return bool(pattern) and any(pattern.search(f["path"]) for f in view.get("files", []))


def head_time(view):
    stamp = view["commits"][-1]["committedDate"]
    return datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp()


def refusal_reason(message, number, head_ts):
    """Why this message does not approve merging PR `number`, or None when it does."""
    # ponytail: an unrelated message sent after the newest commit passes; binding it to the question needs the undocumented transcript
    if not message:
        return "no developer message is on record in this session"
    if message["ts"] <= head_ts:
        return "the developer's last message is older than the PR's newest commit"
    if REFUSAL.match(message["prompt"]):
        return "the developer's last message reads as a refusal"
    named = {int(n) for n in NAMED_PR.findall(message["prompt"])}
    if named and number not in named:
        return "the developer's last message names a different PR"
    return None


def check(data):
    if data.get("tool_name") != "Bash":
        return
    merges = parse_merges(data.get("tool_input", {}).get("command", ""))
    if not merges:
        return
    cwd = data.get("cwd") or "."
    pattern = hold_pattern(cwd)
    path = store_path(cwd)
    messages = load(path) if path else {}
    for pr, repo in merges:
        view = gh_view(pr, repo, cwd)
        if not is_held(view, pattern):
            continue
        reason = refusal_reason(messages.get(data.get("session_id")), view["number"], head_time(view))
        if reason:
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason":
                    f"PR #{view['number']} is held for the developer (ADR 0007) and {reason}. "
                    "Ask them in chat with a `Needs you:` line; any phrasing answers it.",
            }}))
            return


if __name__ == "__main__":
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8"))
        {"record": record, "check": check}[sys.argv[1]](data)
    except Exception as e:  # a broken backstop must never stop the developer's work
        print(f"held_merge: {e}", file=sys.stderr)
    sys.exit(0)
