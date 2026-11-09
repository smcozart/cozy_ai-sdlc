# A held merge needs the developer's own words, checked by a hook

**Issue:** to be filed on adoption · **Status:** proposed (2026-11-08, branch
`windows/lean-chat-approval`); takes effect on adoption. 0007 is the next free
number on main; if another ADR is adopted first, this one renumbers.
**Lightly measured:** unit and scripted checks only, no eval run and
no real held merge yet.

The developer now answers a held PR, or an irreversible or production action,
in chat and in any phrasing; they do not leave the app or open a URL. That
makes it easy for the agent that wants the merge to decide it has been
approved, so the skill text alone is not enough for the one rule that must
hold. As Anthropic's playbook puts it: "A skill is an advisory control while a
hook is the deterministic layer behind it."

**Decision.** `plugin/hooks/held_merge.py` adds two hooks. A UserPromptSubmit
hook records the developer's latest message, per session, in the repo's git
directory. A PreToolUse hook on `gh pr merge` works out whether the PR is held
(a `flagged-risk` or `ready-for-human` label, or a changed path on `LANE_HOLD`)
and, only then, denies the merge unless that message arrived after the PR's
newest commit, is not a plain refusal, and names no other PR. Agent-originated
messages (task notifications, teammate and cross-session messages) are not
recorded. Unheld merges pass untouched, and a repo with no hold list is
ignored. `plugin/hooks/` joins `LANE_HOLD`, because it now checks other files.

**Why this differs from ADR 0006.** ADR 0006 removed two hooks because they
exited 0, blocked nothing and printed on every prompt and every Bash call. This
one blocks, prints nothing, and starts only for `gh pr merge` (an `if` filter);
the prompt hook writes one small file and says nothing.

**Limits.** It is a backstop against a mistaken self-approval, not a security
boundary. An agent with a shell could write the record itself. An unrelated
message sent after the newest commit passes; only the skill's reading of the
answer covers that, because binding the message to the question needs the
undocumented transcript format. `gh api` merges are not seen. A hook failure
warns and allows, so it can never stop work; the skill and the `gate` check
remain. Run the checks with `python3 tests/test_held_merge.py`.

**Rejected.** *Require a fixed phrase*: that is the friction being removed.
*Fail closed on hook errors*: a backstop that can stop the developer's work is
the cost ADR 0006 removed.
