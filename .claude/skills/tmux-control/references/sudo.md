# Sudo And Root Terminal Policy

## Problem

Claude-style opaque shell execution can approve a `sudo` command but still leave the password prompt unreachable. The result is a stuck command and a frustrated user who must replay the command manually.

## Policy

- Do not run `sudo` through opaque Bash; redirect it to a visible root-terminal request.
- Do not hide password, MFA, keychain, or credential prompts in a non-visible process.
- Prefer redesigning the task to avoid privilege only when the replacement is a true equivalent for the user's request.
- Always disclose when the best direct execution appears to need elevated privileges, even if an equivalent lesser-privilege path is available.
- If privilege is necessary, use either a user-run command or an explicitly approved root tmux terminal.
- Stop and request the sudo/root-tmux path when the no-root alternative is partial, temporary, non-portable, or changes the intended environment.

## Privilege Boundary After Failure

This policy also applies when the agent did not type `sudo`, but a command fails with a privilege signal such as `Permission denied`, `Operation not permitted`, `EPERM`, `CAP_SYSLOG`, or "must be root".

In that case:

1. Say that the direct path appears to require elevated privileges.
2. Name the privileged command or root-tmux request that would run the direct path.
3. Use a lesser-privilege result only if it is equivalent for the user's request.
4. If the lesser-privilege route is a compromise, stop and ask for root access before building on it.
5. Cheap read-only context may be provided while requesting root access when it does not change the workflow.

## User-Run Path

Use this when privilege is needed for a small command:

```text
This command may prompt for your password, so I should not run it in the opaque shell. Please run:

<command>

Then paste the output here.
```

## Root Tmux Path

Use this when several privileged commands are required and the user wants the agent to continue in a visible terminal.

Requirements:

- Ask for approval before creating or using the root terminal.
- Scope the root session to one task.
- Use a clear session name such as `root-install-venv` or `root-docker-setup`.
- Keep prompts visible to the user.
- Close or de-escalate the root session after the scoped work is done.

Suggested wording:

```text
This needs elevated privileges and may prompt for your password. I should not run it in the opaque shell. Please either run the command yourself and paste the output, or approve a visible root tmux session named <session> for this task.
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
