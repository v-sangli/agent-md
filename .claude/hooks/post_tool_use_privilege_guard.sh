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
  *".claude/skills/tmux-control/scripts/tmux_control.sh root-request"*) exit 0 ;;
esac

# Only error/stderr text counts as a privilege signal. Scanning every string
# in the payload (including stdout) made reading any file that merely contains
# the words "Operation not permitted" fire this advisory.
event_text="$(
  printf '%s' "$payload" |
    jq -r '[(.error // empty), (.tool_response.stderr // empty), (.tool_response.error // empty)] | map(tostring) | join("\n")' 2>/dev/null |
    tr '[:upper:]' '[:lower:]' || true
)"
hook_event="$(printf '%s' "$payload" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null || printf 'PostToolUse')"

privilege_signal='permission denied|operation not permitted|eperm|eacces|must be root|requires root|requires [a-z -]*privilege|cap_syslog|dmesg_restrict|superuser|administrator privileges'
privileged_command='(^|[;&|()[:space:]])(dmesg|mount|umount|modprobe|insmod|rmmod|sysctl[[:space:]]+-w|journalctl[[:space:]]+(-k|--dmesg)|systemctl[[:space:]]+(start|stop|restart|enable|disable)|apt(-get)?[[:space:]]+(install|remove|purge|upgrade)|dpkg[[:space:]]+-i)([[:space:]]|$)'

if ! printf '%s\n' "$event_text" | grep -Eiq "$privilege_signal"; then
  if [ "$hook_event" != "PostToolUseFailure" ] || ! printf '%s\n' "$command_text" | grep -Eq "$privileged_command"; then
    exit 0
  fi
fi

safe_name="$(
  printf '%s' "$command_text" |
    tr '[:upper:]' '[:lower:]' |
    sed 's/[^A-Za-z0-9._-]\+/-/g; s/^-//; s/-$//; s/^\(.\{1,40\}\).*/\1/'
)"
[ -n "$safe_name" ] || safe_name="privileged-task"
quoted_command="$(
  printf '%s' "$command_text" |
    sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
)"
root_request=".claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-$safe_name --cwd \"\$PWD\" --command $quoted_command"

message="$(cat <<EOF
Privilege boundary detected after Bash command:
\`$command_text\`

Apply the workspace privilege rule:
- Say that the best direct execution appears to need elevated privileges.
- Do not suggest in-session \`! sudo\` or direct opaque-shell sudo as a fallback.
- Use a lesser-privilege path only if it is a true equivalent for this request and does not create a brittle foundation for later work.
- If the workaround is partial, temporary, non-portable, or changes the intended environment, stop and request an approved visible root tmux session before continuing.
- If you provide a no-root result, still mention the root path and why it was not required.

Root-request helper:
\`$root_request\`
EOF
)"

jq -n --arg hook_event "$hook_event" --arg message "$message" \
  '{hookSpecificOutput:{hookEventName:$hook_event,additionalContext:$message}}'
