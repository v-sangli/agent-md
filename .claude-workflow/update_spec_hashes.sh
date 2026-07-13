#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v jq >/dev/null 2>&1 || {
  printf 'update_spec_hashes.sh requires jq\n' >&2
  exit 2
}

files=(
  "CLAUDE.md"
  "HARNESS_CHECKLIST.md"
  ".claude/access.conf"
  ".claude/settings.json"
  ".claude/harness/run.sh"
  ".claude/hooks/access_guard.sh"
  ".claude/hooks/session_start.sh"
  ".claude/hooks/pre_tool_use_guard.sh"
  ".claude/hooks/pre_tool_use_bash_guard.sh"
  ".claude/hooks/post_tool_use_privilege_guard.sh"
  ".claude/skills/tmux-control/SKILL.md"
  ".claude/skills/tmux-control/scripts/tmux_control.sh"
)

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
  printf '{\n'
  printf '  "version": 1,\n'
  printf '  "generated_utc": %s,\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ | jq -R .)"
  printf '  "files": {\n'
  for i in "${!files[@]}"; do
    rel="${files[$i]}"
    hash="$(sha256sum "$ROOT_DIR/$rel" | awk '{print $1}')"
    comma=","
    [ "$i" -eq $((${#files[@]} - 1)) ] && comma=""
    printf '    %s: %s%s\n' "$(printf '%s' "$rel" | jq -R .)" "$(printf '%s' "$hash" | jq -R .)" "$comma"
  done
  printf '  }\n'
  printf '}\n'
} >"$tmp"

jq -S . "$tmp" >"$ROOT_DIR/.claude/spec_hashes.json"
printf '%s\n' "$ROOT_DIR/.claude/spec_hashes.json"
