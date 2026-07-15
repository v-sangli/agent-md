#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"; ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
STATE_DIR="$ROOT_DIR/.claude/context/state"; mkdir -p "$STATE_DIR"
HANDOFF="${HANDOFF:-$STATE_DIR/handoff.pending}"
CLAUDE_CMD="${CTX_CLAUDE_CMD:-claude}"
FLUSH_SETTLE_SECS="${FLUSH_SETTLE_SECS:-2}"

while true; do
  rm -f "$HANDOFF"
  code=0
  "$CLAUDE_CMD" "$@" || code=$?
  if [ -f "$HANDOFF" ]; then
    # allow the transcript to finish flushing before relaunch (see NOTES_flush_timing.md)
    sleep "$FLUSH_SETTLE_SECS" 2>/dev/null || true
    rm -f "$HANDOFF"
    continue
  fi
  exit "$code"
done
