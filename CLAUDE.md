# Claude Project Context

This repository is a Claude Code workspace/harness under active design. Before changing structure, check `HARNESS_CHECKLIST.md` and update it with the decision being made.

Policy references:
- `.claude/policy/AGENT_RULES.md`: concise runtime contract.
- `.claude/policy/OPERATING_SPEC.md`: full current operating specification.
- `.claude/ENV.md`: environment contract.

## Working rules

- Think before coding: state assumptions, surface ambiguity, and push back when the requested path seems overcomplicated.
- Keep changes surgical. Every changed line should trace to the current request.
- Define success criteria and verify them.
- Use `.claude/skills/tmux-control/` for long-running, interactive, test, install, build, benchmark, nested-agent, or sudo-adjacent shell workflows.
- Redirect direct `sudo` to the tmux-control root-request flow. Do not run `sudo` in an opaque shell, and do not suggest in-session `! sudo` as an alternative.
- For privileged work, the only supported continuation path is an explicitly approved visible root tmux session scoped to the task.
- When a command hits a privilege boundary, say so explicitly. A lesser-privilege path is acceptable only when it is a true equivalent for the request and does not create a brittle foundation for later work.
- If the workaround is partial, temporary, non-portable, or changes the intended environment, stop and request the sudo/root-tmux path before continuing. Cheap read-only context may be shared while asking for root access.
- Keep direct Bash for short read-only inspection only. Write/delete shell commands must run through `.claude/harness/run.sh -- '<command>'`; use tmux-control for long-running, test, install, build, benchmark, nested-agent, or sudo-adjacent work.
- Do not reintroduce `.claude-log/` or `.claude-tools/` without recording the reason in `HARNESS_CHECKLIST.md`.

## Environment contract

Read `.claude/ENV.md` before Python, pytest, uv, dependency, install, or build work.

- Default Python environment: `source ~/miniconda3/bin/activate dexpolicy`.
- Validate with `python -V` and `which python` before building on the environment.
- If activation fails or dependencies are missing, stop and ask before switching environments, installing globally, modifying system Python, or relying on durable workarounds.
- Do not use `PYTHONPATH=.` as a durable fix. It is acceptable only as an explicitly named temporary diagnostic.

## Karpathy guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't improve adjacent code, comments, or formatting unless directly required.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports, variables, and functions that your changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-driven execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```text
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria like "make it work" require constant clarification.

These guidelines are working if there are fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
