# The advisory hooks are removed; enforcement stays in the gate and `.githooks/`

**Issue:** #146 · **Status:** accepted (approved by the operator on #146) ·
**Intent:** `intent/146-remove-duplicate-layers/intent.md`; reverses the
advisory part of `intent/21-hooks-core/intent.md`.

The plugin's `hooks/hooks.json` carried two Claude Code hooks: a
UserPromptSubmit workflow reminder and the PostToolUse "close without proof"
advisory from #21. Both exited 0 and blocked nothing, so they enforced
nothing, and they printed on every prompt and every Bash call. **Decision:**
both hooks are removed, with `plugin/hooks/hooks.json` and the `hooks-json`
check that held its shape. Enforcement does not change: it stays in the gate
(`tests/validate.sh`, the required `gate` check) and in the committed git
hooks `.githooks/pre-commit` (the sync rule) and `.githooks/pre-push` (the
gate over the pushed range), which block.
