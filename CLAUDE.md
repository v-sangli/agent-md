# Claude Project Context

This repository is a Claude Code workspace/harness under active design. Before changing structure, check `HARNESS_CHECKLIST.md` and update it with the decision being made.

Sources:
- `.claude/policy/OPERATING_SPEC.md`: design rationale and acceptance criteria. Read it before changing the harness shape.
- `.claude/ENV.md`: environment contract.

## Conventions

As of 2026-07-26 the blocking hook enforcement is rolled back (see
`HARNESS_CHECKLIST.md`): these are conventions and defaults, not gates. Follow
them unless there is a concrete reason not to.

1. Workspace boundary.
- Write/delete work stays inside the repo unless the user grants external scope.
- Treat `.claude/**` as setup configuration: edit it for harness maintenance,
  not as part of ordinary task work.

2. Shell execution.
- Direct Bash is fine for any command, including writes, deletes, and `rm -rf`
  inside the workspace.
- Prefer `tmux-control` for tests, installs, builds, benchmarks, nested agents,
  and long-running work: the user gets a visible, attachable session and a
  durable log. This is encouragement, not a gate.
- Invoke helper scripts with absolute paths, or `cd` to the workspace root
  first — the persistent shell cwd drifts between Bash calls.
- Do not poll with a foreground `sleep`; the harness blocks it. Wait on a
  condition with `tmux_control.sh wait` or the `Monitor` tool.

3. Privilege.
- Prefer the `tmux-control` root-request flow for sudo work: Claude Code's
  opaque shell cannot surface password prompts. Default to a shared root tmux
  session: the user opens it with sudo on its own socket and grants this user
  access (`server-access -a`), the agent drives it via `TMUX_CONTROL_SOCKET`
  while the user watches, and closes it when the scoped task is done.
- Plain `sudo` prompts through permissions; acceptable when the user is
  present and the command is short.

4. Environment.
- Read `.claude/ENV.md` before Python, pytest, uv, dependency, install, or build work.
- Use the default environment named in `.claude/ENV.md` unless the user overrides it.
- Do not use `PYTHONPATH=.` as a durable fix.

5. External monkey patches.
- Do not patch `site-packages`, system paths, external dependency checkouts, or other outside-repo code without explicit approval.
- Prefer in-repo fixes, dependency pins/upgrades, wrappers, or vendored patches.

6. Change discipline.
- Extend existing modules/helpers before adding parallel systems.
- Propose subsystem-level refactors first; use a worktree for non-trivial refactors when practical.
- `Read` a file before `Write`/`Edit`. The tools reject an unread target, so
  guessing at contents costs a round-trip and buys nothing.

7. Verification.
- Define success criteria before substantial edits.
- Run the smallest meaningful validation after edits.
- For harness changes, `bash .claude/verify_setup.sh` is the baseline verifier.

## Worktrees and commits

These override any skill, tool description, or background-session guidance that says otherwise.

**Worktrees are a judgement call, default off.**

- Work directly in this workspace. Do not create or enter a worktree on your own initiative.
- Only when the work is a major undertaking — broad cross-repo refactor, risky long-running migration, or parallel jobs that would collide on the same files — stop and ask whether a worktree is wanted. Do not enter one without agreement.
- `worktree.bgIsolation: "none"` is set so background jobs write to real checkouts directly. That is deliberate. The guard is per-git-repo: when the workspace root is not itself a repo and holds several sub-repos, also set it in user-scope `~/.claude/settings.json`, because the agent cannot write a sub-repo's `.claude/settings.json` once the guard is active.

**Do not commit unless asked.**

- No `git commit`, `git commit --amend`, or `git push` unless I request it in that message.
- This applies to plan checkpoints and end-of-task wrap-up too. Leave the work in the working tree and report what changed and where.

## Shell command shape

Applies to subagents and Monitor/watcher commands too.

- Never use `$(...)` or backticks. Command substitution cannot be checked statically, so
  it always raises an approval prompt that no allowlist can suppress — that prompt has no
  "don't ask again" option. Rewrite without it.
- To wait on a process: `while pgrep -f "[p]attern" >/dev/null; do sleep 5; done`. Test the
  exit status directly; no `$(pgrep ...)` + `kill -0` needed. The bracket around the first
  character keeps `pgrep -f` from matching the waiting loop's own command line — without it
  the loop matches itself and never exits.
- Keep paths inside the workspace or the session scratchpad. Anything else leaves the sandbox and prompts.

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
