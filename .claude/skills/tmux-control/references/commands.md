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

## Stop And Cleanup

```bash
# one session, when its work is done
.claude/skills/tmux-control/scripts/tmux_control.sh stop --session project-work
# every session this Claude session started (skips `start --keep` ones)
.claude/skills/tmux-control/scripts/tmux_control.sh cleanup
```

## Root Request

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh root-request \
  --session root-project-install \
  --cwd "$PWD" \
  --command 'apt install python3.12-venv'
# user attaches and types the password; then:
.claude/skills/tmux-control/scripts/tmux_control.sh wait \
  --target root-project-install::root --pattern '^root@' --timeout 600
.claude/skills/tmux-control/scripts/tmux_control.sh send \
  --target root-project-install::root --command 'apt install -y python3.12-venv'
.claude/skills/tmux-control/scripts/tmux_control.sh stop --session root-project-install
```

## Attach

```bash
tmux attach -t project-work
```
