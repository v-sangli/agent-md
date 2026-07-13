#!/usr/bin/env bash
set -euo pipefail

payload="$(cat || true)"
if [ -z "$payload" ] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || true)"
[ "$tool_name" = "Bash" ] || exit 0

command_text="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[ -n "$command_text" ] || exit 0

case "$command_text" in
  *"tmux "*|*".claude/skills/tmux-control/scripts/tmux_control.sh"*|*".claude/harness/run.sh"*|"bash .claude/verify_setup.sh"*|"bash ./.claude/verify_setup.sh"*)
    exit 0
    ;;
esac

if printf '%s\n' "$command_text" | grep -Eq '(^|[;&|()[:space:]])sudo([[:space:]]|$)'; then
  safe_name="$(
    printf '%s' "$command_text" |
      tr '[:upper:]' '[:lower:]' |
      sed 's/[^A-Za-z0-9._-]\+/-/g; s/^-//; s/-$//; s/^\(.\{1,40\}\).*/\1/'
  )"
  [ -n "$safe_name" ] || safe_name="sudo-task"
  quoted_command="$(
    printf '%s' "$command_text" |
      sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
  )"
  cat >&2 <<EOF
Redirect: sudo in Claude Code's opaque Bash or in-session ! commands can hang at an unreachable password prompt. Use the visible root-terminal request flow instead:
.claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-$safe_name --cwd "\$PWD" --command $quoted_command
EOF
  exit 2
fi

long_or_mutating='(^|[;&|()[:space:]])(python|python3|pytest|uv|pip|pipx|npm|pnpm|yarn|bun|cargo|make|cmake|go|bash[[:space:]]+-c|sh[[:space:]]+-c|git[[:space:]]+clone|git[[:space:]]+pull|git[[:space:]]+checkout|git[[:space:]]+switch|git[[:space:]]+worktree|bugsinpy-|claude)([[:space:]]|$)'
if printf '%s\n' "$command_text" | grep -Eq "$long_or_mutating"; then
  cat >&2 <<'EOF'
Blocked: run benchmark, test, install, clone, and long-running agent commands through tmux for transparency and persistence. Use the tmux-control skill or .claude/skills/tmux-control/scripts/tmux_control.sh.
EOF
  exit 2
fi

access_decision="$(
  printf '%s' "$payload" |
    CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}" bash "${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/hooks/access_guard.sh" 2>/dev/null || true
)"
if [ -n "$access_decision" ]; then
  cat >&2 <<'EOF'
Blocked: direct Bash write/delete commands must run through the script harness.
Use:
  .claude/harness/run.sh -- '<command>'
EOF
  printf '%s\n' "$access_decision" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' >&2 || true
  exit 2
fi

first_word="${command_text%%[[:space:]]*}"
case "$first_word" in
  pwd|ls|find|rg|grep|egrep|fgrep|sed|awk|cat|head|tail|wc|nl|sort|uniq|stat|file|du|df|which|whereis|command|realpath)
    exit 0
    ;;
esac

exit 0
