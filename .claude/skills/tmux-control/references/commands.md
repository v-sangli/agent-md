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

## Run

Send + wait-for-completion + scoped capture + exit code, in one call. Prefer
this over `send`/sleep/`capture` and over hand-rolled sentinel poll loops.
Output is sliced to exactly this run (no stale scrollback), auto-captured to
`.tmux-control/captures/<ts>-<label>.log` with the exit code in the matching
`.ec` file, and the command's exit code becomes `run`'s own (124 on timeout).
The payload is sourced in the pane shell, so `conda activate` etc. persists.

```bash
.claude/skills/tmux-control/scripts/tmux_control.sh run \
  --target project-work::run \
  --command 'pytest -q' \
  --label pytest-core \
  --timeout 600 \
  --tail 60
```

Multi-line payloads: pass `--command -` and pipe the script on stdin (avoids
one whole layer of quoting):

```bash
printf '%s\n' 'set -x' 'make build' 'make test' |
  .claude/skills/tmux-control/scripts/tmux_control.sh run \
    --target project-work::run --command - --label build-test --timeout 900
```

On timeout the command keeps running in the pane; follow up with `wait-for`
or `interrupt`.

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
