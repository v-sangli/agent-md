#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

payload="$(cat || true)"
session_id="manual"
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$payload" | jq -r '.session_id // "manual"' 2>/dev/null || printf 'manual')"
fi

cat <<EOF
STATE REINJECTION
SESSION_ID: $session_id

RULE SNAPSHOT:
- Use the tmux-control skill for long-running, interactive, test, install, build, benchmark, or nested-agent shell work.
- Do not run sudo in an opaque shell. Ask the user to run it or request an explicitly approved visible root tmux session.
- If a command hits a privilege boundary, disclose it. Use lesser privileges only for true equivalents; stop for root access when the workaround is partial, temporary, or non-portable.
- Normal task agents must not edit .claude/** unless the user is intentionally maintaining this Claude setup.
EOF
