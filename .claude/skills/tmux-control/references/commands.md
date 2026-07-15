# Tmux Command Reference

Run these commands from the project root.

## Start

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh start \
  --session project-work \
  --root "$PWD" \
  --roles run,logs \
  --replace
```

## Send

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh send \
  --target project-work::run \
  --command 'pytest -q'
```

## Capture

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh capture \
  --target project-work::run \
  --lines 200 \
  --join-wrapped \
  --output .tmux-control/captures/project-work.txt
```

## Wait-for

Poll a pane until output matches an ERE (prints the pane tail; exits 1 on
timeout). Prefer this over hand-rolled `for`/`sleep`/`capture` loops.

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh wait-for \
  --target project-work::run \
  --pattern '[0-9]+ passed|[0-9]+ failed|error' \
  --timeout 120 \
  --lines 60
```

## Status

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh status --session project-work
```

## Interrupt

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh interrupt --target project-work::run
```

## Root Request

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh root-request \
  --session root-project-install \
  --cwd "$PWD" \
  --command 'sudo apt install python3.12-venv'
```

## Attach

```bash
tmux attach -t project-work
```
