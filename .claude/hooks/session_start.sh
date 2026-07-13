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

RULE SOURCES:
- .claude/policy/AGENT_RULES.md is the canonical short runtime contract.
- .claude/policy/OPERATING_SPEC.md explains design rationale and acceptance criteria.
- .claude/ENV.md identifies the default Python environment.

POINTERS:
- Use tmux-control when work needs visible shell execution.
- Use bash .claude/verify_setup.sh after harness changes.
EOF
