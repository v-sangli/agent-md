# Validation

Use this file when validating this skill.

## Skill Folder

Validate the skill metadata (the skill folder must have `SKILL.md` with name and
description frontmatter, plus the `scripts/` and `references/` it points at):

```bash
bash .claude/verify_setup.sh
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

The output must ask the user to approve a visible root tmux session. It must not suggest in-session `! sudo`, ask for paste-output execution, or execute `sudo`.

## Expected Behavior

No tool call is blocked — the harness is advisory (see
`.claude/policy/OPERATING_SPEC.md`). The verifier should prove:

- `root-request` offers only a visible root tmux session; it never suggests
  in-session `! sudo` or executes `sudo` itself.
- The state dir is anchored to the workspace, so `start` and `capture` resolve
  the same alias file even when the shell cwd drifts between calls.
- The user can attach with `tmux attach -t <session>`.
