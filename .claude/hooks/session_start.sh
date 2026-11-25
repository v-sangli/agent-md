#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

payload="$(cat || true)"
session_id="manual"
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$payload" | jq -r '.session_id // "manual"' 2>/dev/null || printf 'manual')"
fi

agent_docs_status="$(bash "$ROOT_DIR/.claude/skills/agent-docs/scripts/agent_docs.sh" check 2>&1 || true)"

cat <<EOF
STATE REINJECTION
SESSION_ID: $session_id

RULE SOURCES:
- CLAUDE.md (Conventions) is the canonical short runtime contract.
- .claude/policy/OPERATING_SPEC.md explains design rationale and acceptance criteria.

AGENT DOCS: workspace facts in ~/.agent-docs/; CLAUDE.md imports its index.
- $agent_docs_status

POINTERS:
- A code change in a repo starts with the dev-flow skill.
- Use tmux-control when work needs visible shell execution.
- Learned or were given a workspace fact? Record it with the agent-docs skill.
- Need sudo/root? FIRST option is always tmux-control root-request (user-owned
  session + \`sudo -i\` in the pane). Never \`sudo tmux\`; never opaque sudo.
- Stop every tmux session you started when its work is done:
  tmux_control.sh stop --session NAME (or cleanup for all of yours).
- Use bash .claude/verify_setup.sh after harness changes.
EOF
