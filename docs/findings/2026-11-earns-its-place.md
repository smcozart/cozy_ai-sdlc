# What earns its place in ai-sdlc (November 2026 review)

**Tested on:** Windows 11 with Git Bash, on `claude-opus-5-5`, ai-sdlc 1.8.3 with its required dependency mattpocock-skills. **Not yet reviewed on macOS.** Treat every proposal here as adopt-or-discard.

## The stance this review recommends

ai-sdlc is a **long-term maintenance system**. Its job is to make a project understandable and safe to change months from now. It should do that **in the background**, without changing how a person develops. The test for each component is: does it pay for itself without adding friction to the actual dev process?

Direction comes from [Anthropic's AI-Native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook), the origin of this system: "Every session checks its own work before a human sees it," and an approval prompt during the build "puts a person back on the critical path."

## Bottom line

**The records earn their place. The live workflow around them, as built today, does not.**

| Finding | Number |
|---|---|
| Real long-running projects: facts recovered and tasks done, with records kept vs never kept | **23/25 vs 12/25** (p=0.001) |
| Same projects: plugin loaded vs records alone | 21/25 vs 23/25 (p=0.67), no gain from the live skills when reading records |
| Short-session cost vs the same repo without the plugin (budget was 1.25x) | feature request **2.6x**, decision record **2.9x**, catch-up **1.5x** |
| Six fresh sessions on one project | **3.6–4.1x** cost |
| A reversal the developer asked for, held at the approval gate | **0/5** vs 3/5 without the plugin (stale rule used 5/5, p=0.008) |
| Durable, shared decision record written | **5/5** vs 1/5 without the plugin (p=0.048); a plain repo wrote a doc 4/5 |

## Component by component

| Component | Verdict | Evidence |
|---|---|---|
| Records: ADRs, intent files, issue trail | **Keep** | They decide the outcome on long histories. Facts held only in records were lost without them (0/5 on four separate facts) |
| Repo conventions (`AGENTS.md` and friends) | **Keep** | Tested together with the records on long histories, so their separate effect is unknown. On small young repos alone: no outcome gain at about 1.4x cost |
| Record-writing in `intent-conversation` | **Keep** | The plugin's one measured live win (5/5 vs 1/5) |
| Approval ritual in `intent-conversation` | **Lean out** | Withheld an explicit request. Approval depends on specific phrasing |
| Issue, intent, worktree and dispatch on small changes | **Lean out** | Main source of the 2.6x. The extra calls are GitHub writes, worktrees and skill loads |
| `dispatch` for large or parallel work | **Keep, opt-in** | Not measured at the scale it's built for |
| Adversary pass | **Keep** | Caught a real bug that hidden tests missed (an export that could overwrite the database) |
| `tests/validate.sh` gate | **Keep** | Not A/B tested, but it is what proved the Windows fixes |
| Auto-merge on green with the hold list (ADR 0005) | **Keep** | Not A/B tested. Already matches the direction of this review |
| Post-merge human review of every diff | **Lean out** | Not tested. Friction with no measured return |
| `cmu` | **Unproven** | Same accuracy as reading the repo, at 1.5–1.7x cost. Keep only if you value the format |
| `new-project` | **Not tested** | It writes the conventions that proved valuable, so it has an indirect case |

**The defect most worth fixing** is the approval gate. "Please update what's already there" was treated as not approved, so the change never landed and later sessions kept building on the old rule.

**The gap most worth closing:** on a request that conflicted with an earlier decision, 3 of 5 plugin runs never mentioned that ADR 0006 had removed that hook on purpose, against 0 of 5 for records alone. Tests cannot catch this class of mistake, because nothing fails.

## Mapped to the playbook's six stages

| Stage | Today | Proposed |
|---|---|---|
| **Plan** | Issue and intent file before any work, then a separate "go" | The request is the approval. Intent files only for large or risky work |
| **Design** | ADRs on a records branch with its own PR | Settled decisions recorded in the same turn on the working branch; flag conflicts with earlier decisions |
| **Build** | Dispatch and a worktree per change | Same session for small changes; dispatch is opt-in |
| **Test** | The gate | Keep it. Add real-behaviour verification at the PR (written proposal only) |
| **Deploy** | Auto-merge on green; held files need a human | Keep. Held changes are approved in chat, in any phrasing |
| **Maintain** | Every landed diff owes human review | Records and catch-up stay; review after merge becomes optional sampling |

## On human review: an open decision

The developer's view is that verification, not human PR review, should be the answer. **This review did not test human review**, since the simulated developer merged everything unread.

The evidence that bears on it:
- **For:** independent automated checks found real problems, including bugs in this review's own harness.
- **Against relying on tests alone:** decision conflicts pass every test. That is why the proposals add a check of each diff against the ADRs and intent.
- **Playbook:** it reserves human review for "regulated and critical code," but also says "branch protection still requires approval from a code owner." Removing human approval entirely goes a step past the playbook, deliberately.

What's proposed stays human only for changes to the checks themselves (so an agent can't weaken its own gate) and for irreversible or production actions.

## Proposals

Each is a separate PR cut from `main`, to be merged or closed on its own. Some touch the same files, so the order of adoption may require small conflict fixes.

1. An explicit request counts as approval
2. A small-change path with no issue, intent, worktree or dispatch
3. Decisions always recorded, without a separate records PR
4. Chat approval for held changes, backed by a small hook
5. Review after merge becomes optional
6. A check of each change against earlier decisions
7. A real-behaviour verification layer (written proposal, no code)

## How far to trust this

- 5 runs per setup, so only large effects show. Several gaps are not statistically significant.
- Controlled tasks. Real permission prompts, several workers in parallel, and months of real use were not tested.
- Long-history answers were scored blind by two labellers, who agreed on 15/15 pass/fail decisions and 72/72 facts. Blinding was only partial: answers from the no-records setup announce that records are missing.
- "Records never kept" measures the value of having records, not the value of the plugin that wrote them.
- A design decided after seeing data (answering approval questions) is reported separately and never pooled.
- A first version of the harness double-counted cost across resumed sessions. All figures here are corrected.

Full evidence (private): `smcozart/cozysuite_review_evidence`.
