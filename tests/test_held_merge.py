"""Checks for plugin/hooks/held_merge.py (ADR 0007). Run: python3 tests/test_held_merge.py"""
import contextlib
import io
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.dont_write_bytecode = True  # a .pyc under plugin/ would trip the adr-refs grep
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "plugin" / "hooks"))
import held_merge as hm

# parsing: chained commands, flags with values, a URL, no number, the repo flag
assert hm.parse_merges("git status") == []
assert hm.parse_merges("gh pr view 3") == []
assert hm.parse_merges("gh pr merge 12 --squash") == [("12", None)]
assert hm.parse_merges("cd x && gh pr merge --squash --match-head-commit abc 12") == [("12", None)]
assert hm.parse_merges("gh pr merge -R o/r 7") == [("7", "o/r")]
assert hm.parse_merges("gh pr merge --repo=o/r --squash") == [(None, "o/r")]
assert hm.parse_merges("gh pr comment 3 --body-file f; gh pr merge 3\ngit push") == [("3", None)]

# held: label or path; only those
pat = re.compile(r"^(tests/validate\.sh$|\.github/workflows/)")
assert hm.is_held({"labels": [{"name": "flagged-risk"}], "files": []}, None)
assert hm.is_held({"labels": [], "files": [{"path": "tests/validate.sh"}]}, pat)
assert not hm.is_held({"labels": [{"name": "bug"}], "files": [{"path": "src/a.py"}]}, pat)

# approval: any phrasing after the newest commit; not a refusal, not stale, not another PR
now = 1000.0
yes = lambda p, ts=now + 1: {"ts": ts, "prompt": p}
assert hm.refusal_reason(yes("yeah ship it"), 12, now) is None
assert hm.refusal_reason(yes("merge 12 please"), 12, now) is None
assert hm.refusal_reason(yes("sounds good, go ahead with #12"), 12, now) is None
assert "no developer message" in hm.refusal_reason(None, 12, now)
assert "older" in hm.refusal_reason(yes("ok", now - 1), 12, now)
assert "refusal" in hm.refusal_reason(yes("no, wait for CI"), 12, now)
assert "refusal" in hm.refusal_reason(yes("Don't merge that"), 12, now)
assert "different PR" in hm.refusal_reason(yes("merge #13"), 12, now)

# end to end in a throwaway repo: record stores the message, agent-originated text is ignored,
# and check denies, then allows once the developer speaks after the newest commit.
with tempfile.TemporaryDirectory() as d:
    subprocess.run(["git", "init", "-q", d], check=True)
    Path(d, "tests").mkdir()
    Path(d, "tests", "validate.sh").write_text("LANE_HOLD='^tests/validate\\.sh$'\n", encoding="utf-8")
    store = hm.store_path(d)
    hm.record({"session_id": "s", "cwd": d, "prompt": "<task-notification>done</task-notification>"})
    assert not store.exists(), "agent-originated text must not count as the developer"

    hm.gh_view = lambda pr, repo, cwd: {
        "number": 12, "labels": [], "files": [{"path": "tests/validate.sh"}],
        "commits": [{"committedDate": "2020-01-01T00:00:00Z"}]}
    call = {"session_id": "s", "cwd": d, "tool_name": "Bash", "tool_input": {"command": "gh pr merge 12 --squash"}}

    def decision():
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            hm.check(call)
        return out.getvalue()

    assert json.loads(decision())["hookSpecificOutput"]["permissionDecision"] == "deny"
    hm.record({"session_id": "s", "cwd": d, "prompt": "looks fine, go ahead"})
    assert json.loads(store.read_text(encoding="utf-8"))["s"]["prompt"] == "looks fine, go ahead"
    assert decision() == ""

    hm.gh_view = lambda pr, repo, cwd: {
        "number": 12, "labels": [], "files": [{"path": "src/a.py"}],
        "commits": [{"committedDate": "2020-01-01T00:00:00Z"}]}
    call["session_id"] = "other"
    assert decision() == "", "an unheld merge is never blocked"

    # a repo with no hold list records nothing
    with tempfile.TemporaryDirectory() as e:
        subprocess.run(["git", "init", "-q", e], check=True)
        hm.record({"session_id": "s", "cwd": e, "prompt": "hello"})
        assert not hm.store_path(e).exists()

print("held_merge: all checks passed")
