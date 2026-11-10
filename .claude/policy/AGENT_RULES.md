# Agent Rules

This is the canonical short runtime contract for this Claude workspace. As of
2026-07-26 the blocking hook enforcement is rolled back (see
`HARNESS_CHECKLIST.md`): these are conventions and defaults, not gates. Follow
them unless there is a concrete reason not to. Design rationale lives in
`.claude/policy/OPERATING_SPEC.md`.

## Conventions

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
- Clean up your own tmux sessions: `tmux_control.sh stop --session NAME` when
  a session's work is done, or `tmux_control.sh cleanup` to stop every session
  this Claude session started. Pass `start --keep` only for a service the user
  wants left running, and report it. Never stop sessions you did not start.
- Invoke helper scripts with absolute paths, or `cd` to the workspace root
  first — the persistent shell cwd drifts between Bash calls.
- Do not poll with a foreground `sleep`; the harness blocks it. Wait on a
  condition with `tmux_control.sh wait` or the `Monitor` tool.

3. Privilege.
- When work needs sudo/root, the root tmux session is the first option you
  offer, before any alternative: `tmux_control.sh root-request`. Claude Code's
  opaque shell cannot surface password prompts; a visible tmux pane can.
- The root session is a user-owned tmux session escalated inside the pane with
  `sudo -i`. Never `sudo tmux ...`: that starts a root-owned tmux server the
  agent cannot reach, and it hides the user's own sessions.
- Send nothing to the pane until the root prompt appears (`wait --pattern
  '^root@'`); earlier keystrokes land in the password prompt.
- `stop` the root session as soon as the scoped work is done.

4. Environment.
- Read `.claude/ENV.md` before Python, pytest, uv, dependency, install, or build work.
- Use the default environment named in `.claude/ENV.md` unless the user overrides it.
- Do not use `PYTHONPATH=.` as a durable fix.

5. External monkey patches.
- Do not patch `site-packages`, system paths, external dependency checkouts, or other outside-repo code without explicit approval.
- Prefer in-repo fixes, dependency pins/upgrades, wrappers, or vendored patches.

6. Change discipline.
- Try at most one minimal hypothesis-driven patch for a new bug before switching to investigation.
- Extend existing modules/helpers before adding parallel systems.
- Propose subsystem-level refactors first; use a worktree for non-trivial refactors when practical.
- `Read` a file before `Write`/`Edit`. The tools reject an unread target, so
  guessing at contents costs a round-trip and buys nothing.

7. Verification.
- Define success criteria before substantial edits.
- Run the smallest meaningful validation after edits.
- For harness changes, `bash .claude/verify_setup.sh` is the baseline verifier.
