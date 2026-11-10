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
.claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-smoke --cwd "$PWD" --command 'true'
tmux has-session -t root-smoke   # reachable without sudo: server is user-owned
.claude/skills/tmux-control/scripts/tmux_control.sh stop --session root-smoke
```

The output must give a plain `tmux attach -t root-smoke` line and the pane must show `sudo -i`. It must never contain `sudo tmux`, suggest in-session `! sudo`, or ask for paste-output execution.

## Expected Behavior

No tool call is blocked — the harness is advisory (see
`.claude/policy/OPERATING_SPEC.md`). The verifier should prove:

- `root-request` opens a user-owned session and types `sudo -i` into its pane;
  it never uses `sudo tmux` or suggests in-session `! sudo`.
- `cleanup` stops only sessions tagged with the caller's
  `CLAUDE_CODE_SESSION_ID`, and skips `--keep` sessions.
- Pane roles are stored as tmux pane options (`@role`); no state directory is
  written, so `SESSION::role` targets resolve from any cwd.
- The user can attach with `tmux attach -t <session>`.
