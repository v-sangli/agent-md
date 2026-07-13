#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ACCESS_GUARD="$ROOT_DIR/.claude/hooks/access_guard.sh"

usage() {
  cat <<'EOF'
Usage:
  .claude/harness/run.sh -- <bash-command>

Executes write/delete shell work only after the Bash access classifier returns ok.
If the command needs approval, this script prints the request and exits without
running the command.
EOF
}

quote_for_payload() {
  jq -n --arg cmd "$1" '{tool_name:"Bash",tool_input:{command:$cmd}}'
}

die() {
  printf 'harness-run: %s\n' "$*" >&2
  exit 2
}

[ "${1:-}" = "--" ] || {
  usage >&2
  exit 2
}
shift
[ "$#" -gt 0 ] || die "missing command"

command_text="$*"

case "$command_text" in
  *".claude/harness/run.sh"*) die "refusing recursive harness invocation" ;;
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
Privilege request required; command was not run.
.claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-$safe_name --cwd "\$PWD" --command $quoted_command
EOF
  exit 3
fi

long_or_mutating='(^|[;&|()[:space:]])(python|python3|pytest|uv|pip|pipx|npm|pnpm|yarn|bun|cargo|make|cmake|go|bash[[:space:]]+-c|sh[[:space:]]+-c|git[[:space:]]+clone|git[[:space:]]+pull|git[[:space:]]+checkout|git[[:space:]]+switch|git[[:space:]]+worktree|bugsinpy-|claude)([[:space:]]|$)'
if printf '%s\n' "$command_text" | grep -Eq "$long_or_mutating"; then
  cat >&2 <<'EOF'
Harness runner refused this command.
Use tmux-control for tests, installs, builds, benchmarks, nested agents, interpreters, and other long-running or opaque workflows.
EOF
  exit 2
fi

decision_json="$(
  quote_for_payload "$command_text" |
    CLAUDE_PROJECT_DIR="$ROOT_DIR" bash "$ACCESS_GUARD"
)"

if [ -z "$decision_json" ]; then
  cat >&2 <<'EOF'
Harness runner found no classified write/delete targets.
Use direct Bash for short read-only inspection, or pass an explicit write/delete command.
EOF
  exit 2
fi

decision="$(printf '%s' "$decision_json" | jq -r '.hookSpecificOutput.permissionDecision // ""')"
level="$(printf '%s' "$decision_json" | jq -r '.hookSpecificOutput.accessLevel // ""')"
reason="$(printf '%s' "$decision_json" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

case "$level:$decision" in
  ok:allow)
    cd "$ROOT_DIR"
    exec bash -lc "$command_text"
    ;;
  ask:ask)
    cat >&2 <<EOF
Approval required; command was not run.
$reason

To grant external write/delete access, edit .claude/access.conf with a scoped root and rerun this harness command.
EOF
    exit 3
    ;;
  critical:ask)
    cat >&2 <<EOF
Critical approval required; command was not run.
$reason
EOF
    exit 4
    ;;
  *)
    cat >&2 <<EOF
Harness runner could not classify this command; command was not run.
$reason
EOF
    exit 2
    ;;
esac
