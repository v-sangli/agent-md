#!/usr/bin/env bash
set -uo pipefail

# Safety net for agents that forget to stop their tmux sessions: reap this
# Claude session's idle sessions. Never blocks exit.
ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

payload="$(cat || true)"
session_id=""
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi
[ -n "$session_id" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

bash "$ROOT_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh" cleanup --owner "$session_id" --idle-only >/dev/null 2>&1 || true
exit 0
