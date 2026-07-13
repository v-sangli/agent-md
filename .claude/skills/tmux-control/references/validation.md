# Validation

Use this file when validating this skill.

## Skill Folder

Validate the skill metadata:

```bash
python3 /home/vsangli/.codex/skills/.system/skill-creator/scripts/quick_validate.py .claude/skills/tmux-control
```

Smoke-test the helper without running destructive commands:

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh start --session tmux-control-smoke --root "$PWD" --roles run,logs --replace
.claude/skills/tmux-control/scripts/tmux_control.sh send --target tmux-control-smoke::run --command 'printf "tmux-control-ok\n"'
.claude/skills/tmux-control/scripts/tmux_control.sh capture --target tmux-control-smoke::run --lines 20
.claude/skills/tmux-control/scripts/tmux_control.sh status --session tmux-control-smoke
tmux kill-session -t tmux-control-smoke
```

Check the sudo request path:

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-smoke --cwd "$PWD" --command 'sudo true'
```

The output must ask the user to run or approve a visible root tmux session. It must not execute `sudo`.

## Hook Behavior

The project verifier should prove:

- Direct `sudo` in opaque Bash is blocked with user-run or root-tmux guidance.
- Permission/privilege failures after Bash inject guidance to disclose the boundary and request root when no true equivalent exists.
- Direct tests, installs, benchmarks, and nested-agent commands are blocked or redirected to tmux.
- The same commands are allowed when sent through `.claude/skills/tmux-control/scripts/tmux_control.sh`.
- The user can attach with `tmux attach -t <session>`.
