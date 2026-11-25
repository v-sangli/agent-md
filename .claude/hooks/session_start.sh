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
- CLAUDE.md (Conventions) is the canonical short runtime contract.
- .claude/policy/OPERATING_SPEC.md explains design rationale and acceptance criteria.
- .claude/ENV.md identifies the default Python environment.

POINTERS:
- A code change in a repo starts with the dev-flow skill.
- Use tmux-control when work needs visible shell execution.
- Need sudo/root? FIRST option is always tmux-control root-request (user-owned
  session + \`sudo -i\` in the pane). Never \`sudo tmux\`; never opaque sudo.
- Stop every tmux session you started when its work is done:
  tmux_control.sh stop --session NAME (or cleanup for all of yours).
- Use bash .claude/verify_setup.sh after harness changes.
EOF

# prov status (ADR 0011): installed once per machine by .claude-workflow/install_prov.sh,
# which writes the pointer file read here.
pointer="${PROV_POINTER:-$HOME/.config/prov/install.toml}"
echo
if [ -f "$pointer" ]; then
  declare -A prov
  while IFS=' =' read -r key value; do
    case "$key" in ''|'#'*) continue ;; esac
    value="${value#*\"}"; prov[$key]="${value%\"}"
  done <"$pointer"
  echo "PROV: ${prov[ref]} (${prov[commit]:0:7}) at ${prov[home]}"
  echo "- CLIs prov, prov-journal in ${prov[bin]}; skills: ${prov[skills]}."
  echo "- Usage: ${prov[usage]}. A run's own env installs prov from ${prov[home]}/packages/prov."
else
  echo "PROV: not installed on this machine (no $pointer)."
  echo "- To install, propose to the user: bash .claude-workflow/install_prov.sh <release tag>"
fi
dir="$ROOT_DIR"
while [ ! -f "$dir/prov.toml" ] && [ "$dir" != "/" ]; do
  dir="${dir%/*}"; [ -n "$dir" ] || dir="/"
done
if [ -f "$dir/prov.toml" ]; then
  echo "- This workspace is a prov project (prov.toml at $dir): resolve any ID or alias with"
  echo "  prov show / trace / uses before assuming anything about it; cite IDs, never paths."
  if [ -f "$dir/journal/NOW.md" ]; then
    echo "- Read $dir/journal/NOW.md before starting work."
  fi
fi
