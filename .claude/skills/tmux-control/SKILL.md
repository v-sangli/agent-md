---
name: tmux-control
description: Run shell work through visible persistent tmux sessions. Use when Codex needs to run benchmarks, tests, installs, builds, migrations, long-running jobs, nested Claude/agent sessions, interactive debuggers, commands requiring live observation/interruption, or any command involving sudo, credentials, passwords, or root-terminal prompts.
---

# Tmux Control

Use tmux whenever opaque one-shot shell execution would hide progress, prompts, or failures from the user.

## Core Rules

- Run benchmark, test, install, build, clone, migration, server, watcher, debugger, and nested-agent commands in tmux.
- Keep direct shell only for quick read-only inspection such as `pwd`, `ls`, `rg`, `sed`, `cat`, `find`, `head`, `tail`, `wc`, `stat`, `file`, and `git status`.
- For sudo/root work, the root tmux session below is always the first option. Follow `.claude/policy/AGENT_RULES.md` and [references/sudo.md](references/sudo.md).
- Report the attach command, pane roles, and any durable capture location.
- Stop every session you started once its work is done (`stop --session NAME`, or `cleanup` for all of yours). Use `start --keep` only for a service the user wants left running, and say so. Never stop sessions you did not start.

## Start Or Reuse A Session

Use the bundled helper:

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh start --session <name> --root "$PWD" --roles run,logs --replace
.claude/skills/tmux-control/scripts/tmux_control.sh send --target <name>::run --command '<command>'
.claude/skills/tmux-control/scripts/tmux_control.sh capture --target <name>::run --lines 200
.claude/skills/tmux-control/scripts/tmux_control.sh stop --session <name>
```

Sessions are tagged with `$CLAUDE_CODE_SESSION_ID`; `cleanup` stops only yours. A `SessionEnd` hook reaps your idle sessions as a safety net, but do not rely on it.

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

Open the root session (user-owned tmux, `sudo -i` typed into the pane):

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-<task> --cwd "$PWD" --command '<command>'
.claude/skills/tmux-control/scripts/tmux_control.sh wait --target root-<task>::root --pattern '^root@' --timeout 600
```

Relay the printed attach line to the user, wait for the root prompt, then `send` commands. Never `sudo tmux`. Read [references/sudo.md](references/sudo.md) before designing a privileged workflow.

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
