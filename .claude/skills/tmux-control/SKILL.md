---
name: tmux-control
description: Run shell work through visible persistent tmux sessions. Use when Claude needs to run benchmarks, tests, installs, builds, migrations, long-running jobs, nested Claude/agent sessions, interactive debuggers, commands requiring live observation/interruption, or any command involving sudo, credentials, passwords, or root-terminal prompts.
---

# Tmux Control

Use tmux whenever opaque one-shot shell execution would hide progress, prompts, or failures from the user.

## Core Rules

- Run benchmark, test, install, build, clone, migration, server, watcher, debugger, and nested-agent commands in tmux.
- Keep direct shell only for quick read-only inspection such as `pwd`, `ls`, `rg`, `sed`, `cat`, `find`, `head`, `tail`, `wc`, `stat`, `file`, and `git status`.
- For sudo/root behavior, follow `.claude/policy/AGENT_RULES.md` and [references/sudo.md](references/sudo.md).
- Report the attach command, pane roles, and any durable capture location.
- Leave long-running sessions alive unless the user asks for cleanup.

## Start Or Reuse A Session

Use the bundled helper:

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh start --session <name> --root "$PWD" --roles run,logs --replace
.claude/skills/tmux-control/scripts/tmux_control.sh run --target <name>::run --command '<command>' --label <label> --timeout 600
```

`run` is the default workhorse: one call does send + completion-wait + scoped
capture + exit code (no sleep-guessing, no stale scrollback). Reach for the
lower-level `send`/`capture`/`wait-for` when driving interactive processes or
watching an already-running command.

Usage notes:

- Multi-line payload: write it to a file, then `run --command - < file` — no
  quoting layer, and the payload is preserved under `.tmux-control/runs/`.
- On rc=124 the payload keeps running in the pane; resume with the exact
  `wait-for ... DONE_<id>` line the timeout message prints. Never match
  generic markers like `ec=0===` — stale scrollback makes them a footgun.
- From a worktree or nested cwd, invoke the helper by absolute workspace path
  (AGENT_RULES §2): alias state resolves relative to cwd, and a wrong-cwd
  state dir reads stale pane ids (the helper now falls back to live
  pane-title lookup and names the aliases file it read, but don't rely on it).

Read [references/commands.md](references/commands.md) for command examples.

## Pane Roles

Use role names that make the workflow obvious:

- `bench`: setup, checkout, tests, benchmark commands
- `agent`: nested Claude or implementation agent session
- `logs`: tail of durable log files
- `run`: reproducer or application process
- `debug`: debugger/REPL
- `server`: long-running service
- `client`: probes or test client

## Sudo Policy

Generate root-terminal request wording with:

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-<task> --cwd "$PWD" --command '<sudo-command>'
```

Read [references/sudo.md](references/sudo.md) before designing a privileged workflow.

## Logging

For non-trivial tmux workflows, preserve:

- session name
- pane aliases
- attach command
- command transcript or log path
- initial failure output
- final verification output

Use `.tmux-control/captures/` for durable captures.

## Failure Recovery

If a command appears stuck:

1. Capture the pane.
2. Identify whether it is waiting for input, still running, or dead.
3. If waiting for sudo/password input, stop and switch to the approved root tmux request flow.
4. If the process should be interrupted, use the tmux interrupt command.
5. Capture output again after interruption.

## Validation

When changing this skill, read [references/validation.md](references/validation.md).
