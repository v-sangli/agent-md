# Sudo And Root Terminal Policy

This reference expands `.claude/policy/AGENT_RULES.md` for privileged tmux
workflows. If wording drifts, `AGENT_RULES.md` is the canonical source.

## Problem

Claude-style opaque shell execution can approve a `sudo` command but still leave the password prompt unreachable. The result is a stuck command and a frustrated user who must replay the command manually.

## Policy

- Do not run `sudo` through opaque Bash; redirect it to a visible root-terminal request.
- Do not suggest in-session `! sudo`, direct `sudo`, `sudo -S`, or other password workarounds.
- Do not hide password, MFA, keychain, or credential prompts in a non-visible process.
- Prefer redesigning the task to avoid privilege only when the replacement is a true equivalent for the user's request.
- Always disclose when the best direct execution appears to need elevated privileges, even if an equivalent lesser-privilege path is available.
- If privilege is necessary, the visible root tmux session is the first and default option. Offer it before anything else.
- Stop and request the root-tmux path when the no-root alternative is partial, temporary, non-portable, or changes the intended environment.

## Privilege Boundary After Failure

This policy also applies when the agent did not type `sudo`, but a command fails with a privilege signal such as `Permission denied`, `Operation not permitted`, `EPERM`, `CAP_SYSLOG`, or "must be root".

In that case:

1. Say that the direct path appears to require elevated privileges.
2. Name the privileged command and root-tmux request that would run the direct path.
3. Use a lesser-privilege result only if it is equivalent for the user's request.
4. If the lesser-privilege route is a compromise, stop and ask for root access before building on it.
5. Cheap read-only context may be provided while requesting root access when it does not change the workflow.

## Root Tmux Path

Use this whenever privileged execution is required, including one-off commands such as exact `dmesg` reads.

How it works: the agent creates an ordinary (user-owned) tmux session and types
`sudo -i` into its pane. The user attaches, types the password, and the pane
becomes a root shell the agent can drive with `send`/`capture`.

Never start the session with `sudo tmux ...`. That launches a separate
root-owned tmux server: the agent's tmux calls cannot reach it, and sessions
the user created are not visible from it.

Flow:

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh root-request \
  --session root-<task> \
  --cwd "$PWD" \
  --command '<command>'
# relay the printed `tmux attach -t root-<task>` line to the user, then:
.claude/skills/tmux-control/scripts/tmux_control.sh wait \
  --target root-<task>::root --pattern '^root@' --timeout 600
.claude/skills/tmux-control/scripts/tmux_control.sh send \
  --target root-<task>::root --command 'cd <cwd>'
.claude/skills/tmux-control/scripts/tmux_control.sh send \
  --target root-<task>::root --command '<command>'
.claude/skills/tmux-control/scripts/tmux_control.sh stop --session root-<task>
```

Requirements:

- Send nothing to the pane before `wait` sees the root prompt: earlier keys are
  typed into the password prompt. If the prompt is not `root@...`, capture the
  pane and match on `#$` instead. If `wait` times out, capture: sudo may have
  timed out back to a user shell; re-run `root-request`.
- Scope the root session to one task with a clear name such as
  `root-install-venv` or `root-docker-setup`.
- Keep prompts visible to the user; the user typing the password is the approval.
- `stop` the root session as soon as the scoped work is done.
- Do not present a direct user-run/paste-output path as a parallel option.

## Important Boundary

The helper types `sudo -i` into a visible pane. It never handles the password
and never runs `sudo` in Claude's opaque shell.
