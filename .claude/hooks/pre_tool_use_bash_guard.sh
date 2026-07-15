#!/usr/bin/env bash
set -euo pipefail

# Single decider for Bash tool calls. Emits an explicit permissionDecision so
# the native permission engine's compound-command heuristics ("shell
# operators", "simple_expansion", "cd before git") never double-judge commands
# this guard already understands:
#
#   allow -> statically-clean command whose writes (if any) stay inside the
#            workspace / /tmp, or are pre-granted via .claude/access.conf
#   ask   -> genuine write/delete outside the whitelist (reason names the
#            targets; a grant in .claude/access.conf makes it silent)
#   deny  -> sudo (visible root-terminal flow) or interpreter/test/install
#            work (tmux transparency flow); the reason carries the redirect
#   <none> (exit 0, no output) -> not statically classifiable (unknown heads,
#            $(...), eval, git push/reset, ...): fall through to the native
#            permission engine, which will ask. Fail-safe, never fail-open.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$LIB_DIR/lib/command_scan.sh"

payload="$(cat || true)"
if [ -z "$payload" ] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || true)"
[ "$tool_name" = "Bash" ] || exit 0

command_text="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[ -n "$command_text" ] || exit 0

# Pass-through to native rules: bare tmux use and the verify suite keep their
# existing settings.json handling. (run.sh / tmux_control.sh are handled as
# sanctioned heads by the classifier and get explicit allow.)
case "$command_text" in
  *"tmux "*|"bash .claude/verify_setup.sh"*|"bash ./.claude/verify_setup.sh"*)
    exit 0
    ;;
esac

emit() {
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
}

decision="$(cs_decide "$command_text")"

case "$decision" in
  sudo)
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
    emit deny "sudo in Claude Code's opaque Bash or in-session ! commands can hang at an unreachable password prompt. Use the visible root-terminal request flow instead:
.claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-$safe_name --cwd \"\$PWD\" --command $quoted_command"
    exit 0
    ;;
  interpreter)
    emit deny "Run benchmark, test, install, clone, and long-running agent commands through tmux for transparency and persistence. Use the tmux-control skill or .claude/skills/tmux-control/scripts/tmux_control.sh."
    exit 0
    ;;
  native)
    # git push / git reset --hard: native ask rules own these.
    exit 0
    ;;
esac
# decision is now: clean | opaque

# Permission axis: classify write/delete targets and branch on the level.
access_decision="$(
  printf '%s' "$payload" |
    CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}" bash "$LIB_DIR/access_guard.sh" 2>/dev/null || true
)"

if [ -z "$access_decision" ]; then
  # No write/delete targets found.
  if [ "$decision" = "clean" ]; then
    emit allow "Guard: read-only command (all heads classified, no write targets)."
  fi
  # opaque -> native engine decides.
  exit 0
fi

level="$(printf '%s' "$access_decision" | jq -r '.hookSpecificOutput.accessLevel // "ok"' 2>/dev/null || printf 'ok')"
reason="$(printf '%s' "$access_decision" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true)"

case "$level" in
  ok)
    if [ "$decision" = "clean" ]; then
      emit allow "Guard: write/delete targets stay within the workspace, /tmp, or granted roots. $reason"
    fi
    # opaque + ok findings: unknown heads could hide more writes -> native.
    exit 0
    ;;
  ask)
    emit ask "This command writes or deletes outside the workspace and /tmp. Approve to run it once, or grant a root in .claude/access.conf to stop being asked. $reason"
    exit 0
    ;;
  critical)
    emit ask "CRITICAL: this command targets protected or high-risk paths (.claude, .git, system dirs, or a filesystem/home//tmp root). $reason"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
