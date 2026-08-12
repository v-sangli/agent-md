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
