# Sudo And Root Terminal Policy

## Problem

Claude-style opaque shell execution can approve a `sudo` command but still leave the password prompt unreachable. The result is a stuck command and a frustrated user who must replay the command manually.

## Policy

- Do not run `sudo` through opaque Bash; redirect it to a visible root-terminal request.
- Do not suggest in-session `! sudo`, direct `sudo`, `sudo -S`, or other password workarounds.
- Do not hide password, MFA, keychain, or credential prompts in a non-visible process.
- Prefer redesigning the task to avoid privilege only when the replacement is a true equivalent for the user's request.
- Always disclose when the best direct execution appears to need elevated privileges, even if an equivalent lesser-privilege path is available.
- If privilege is necessary, use an explicitly approved visible root tmux terminal.
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

Requirements:

- Ask for approval before creating or using the root terminal.
- Scope the root session to one task.
- Use a clear session name such as `root-install-venv` or `root-docker-setup`.
- Keep prompts visible to the user.
- Close or de-escalate the root session after the scoped work is done.
- Do not present a direct user-run/paste-output path as a parallel option.

Suggested wording:

```text
This needs elevated privileges. I should not run sudo in Claude's opaque shell or suggest in-session ! sudo. Please approve a visible root tmux session named <session> for this scoped task.
```

The bundled helper can generate a concrete request:

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh root-request \
  --session root-<task> \
  --cwd "$PWD" \
  --command '<sudo-command>'
```

## Important Boundary

The helper prints commands for the user. It does not run `sudo` itself.
