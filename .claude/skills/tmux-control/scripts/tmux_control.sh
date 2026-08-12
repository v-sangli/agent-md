#!/usr/bin/env bash
set -euo pipefail

# Anchor the state dir to the workspace, not the caller's cwd: the persistent
# shell cwd drifts between calls, so a relative default made `capture` look for
# the alias file somewhere `start` never wrote it ("no aliases recorded").
# pwd -P fallback so the twin spellings of a path share one state dir.
state_dir="${TMUX_CONTROL_STATE_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd -P)}/.tmux-control}"
case "$state_dir" in /*) ;; *) state_dir="$(pwd -P)/$state_dir" ;; esac

usage() {
  cat <<'EOF'
Usage:
  tmux_control.sh start --session NAME [--root DIR] [--roles a,b,c] [--replace]
  tmux_control.sh send --target SESSION::ALIAS --command COMMAND [--no-enter]
  tmux_control.sh capture --target SESSION::ALIAS [--lines N] [--join-wrapped] [--output FILE]
  tmux_control.sh status [--session NAME]
  tmux_control.sh wait (--target SESSION::ALIAS | --log FILE) --pattern REGEX [--timeout SECS] [--interval SECS]
  tmux_control.sh interrupt --target SESSION::ALIAS
  tmux_control.sh root-request --session NAME [--cwd DIR] --command COMMAND
EOF
}

die() {
  printf 'tmux-control: %s\n' "$*" >&2
  exit 2
}

sanitize() {
  printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^[._-]*//; s/[._-]*$//; s/^$/manual/'
}

alias_file() {
  mkdir -p "$state_dir/sessions"
  printf '%s/sessions/%s.aliases\n' "$state_dir" "$(sanitize "$1")"
}

save_alias() {
  local session="$1" alias="$2" pane="$3"
  printf '%s=%s\n' "$alias" "$pane" >>"$(alias_file "$session")"
}

resolve_target() {
  local target="$1"
  if [[ "$target" != *::* ]]; then
    printf '%s\n' "$target"
    return
  fi

  local session="${target%%::*}"
  local alias="${target#*::}"
  local file
  file="$(alias_file "$session")"
  [ -f "$file" ] || die "no aliases recorded for session '$session'"

  local pane
  pane="$(awk -F= -v key="$alias" '$1 == key { print $2; found=1 } END { exit found ? 0 : 1 }' "$file")" \
    || die "unknown alias '$alias' for session '$session'"
  printf '%s\n' "$pane"
}

send_keys() {
  local target="$1" command="$2" enter="${3:-1}"
  local pane
  pane="$(resolve_target "$target")"
  tmux send-keys -t "$pane" -l "$command"
  if [ "$enter" = "1" ]; then
    tmux send-keys -t "$pane" Enter
  fi
}

cmd_start() {
  local session="" root="." roles="run,logs" replace=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session) session="${2:-}"; shift 2 ;;
      --root) root="${2:-.}"; shift 2 ;;
      --roles) roles="${2:-run,logs}"; shift 2 ;;
      --replace) replace=1; shift ;;
      *) die "unknown start option: $1" ;;
    esac
  done
  [ -n "$session" ] || die "start requires --session"
  root="$(cd "$root" && pwd)"

  if tmux has-session -t "$session" 2>/dev/null; then
    if [ "$replace" = "1" ]; then
      tmux kill-session -t "$session"
    else
      die "session '$session' already exists; pass --replace"
    fi
  fi

  rm -f "$(alias_file "$session")"
  tmux new-session -d -s "$session" -n control -c "$root"
  local first pane role
  first="$(tmux display-message -p -t "$session:control.0" '#{pane_id}')"

  IFS=',' read -r -a role_list <<<"$roles"
  [ "${#role_list[@]}" -gt 0 ] || role_list=(main)

  for i in "${!role_list[@]}"; do
    role="$(printf '%s' "${role_list[$i]}" | xargs)"
    [ -n "$role" ] || continue
    if [ "$i" -eq 0 ]; then
      pane="$first"
    else
      pane="$(tmux split-window -h -d -P -F '#{pane_id}' -t "$first" -c "$root")"
    fi
    tmux select-pane -t "$pane" -T "$role"
    save_alias "$session" "$role" "$pane"
    send_keys "$pane" "cd $(printf '%q' "$root")"
  done

  if [ "${#role_list[@]}" -gt 1 ]; then
    tmux select-layout -t "$session:control" tiled >/dev/null
  fi
  tmux select-pane -t "$first"

  printf 'Started tmux session: %s\n' "$session"
  printf 'Attach: tmux attach -t %s\n' "$session"
  printf 'Aliases: %s\n' "$roles"
  printf 'State: %s\n' "$(alias_file "$session")"
}

cmd_send() {
  local target="" command="" enter=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target) target="${2:-}"; shift 2 ;;
      --command) command="${2:-}"; shift 2 ;;
      --no-enter) enter=0; shift ;;
      *) die "unknown send option: $1" ;;
    esac
  done
  [ -n "$target" ] || die "send requires --target"
  [ -n "$command" ] || die "send requires --command"
  send_keys "$target" "$command" "$enter"
  printf 'Sent to %s: %s\n' "$target" "$command"
}

cmd_capture() {
  local target="" lines=200 join=0 output=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target) target="${2:-}"; shift 2 ;;
      --lines) lines="${2:-200}"; shift 2 ;;
      --join-wrapped) join=1; shift ;;
      --output) output="${2:-}"; shift 2 ;;
      *) die "unknown capture option: $1" ;;
    esac
  done
  [ -n "$target" ] || die "capture requires --target"
  local pane args
  pane="$(resolve_target "$target")"
  args=(capture-pane -p -t "$pane" -S "-$lines")
  if [ "$join" = "1" ]; then
    args+=(-J)
  fi
  if [ -n "$output" ]; then
    mkdir -p "$(dirname "$output")"
    tmux "${args[@]}" >"$output"
    printf '%s\n' "$output"
  else
    tmux "${args[@]}"
  fi
}

cmd_wait() {
  local target="" pattern="" log="" timeout=1800 interval=10
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target) target="${2:-}"; shift 2 ;;
      --pattern) pattern="${2:-}"; shift 2 ;;
      --log) log="${2:-}"; shift 2 ;;
      --timeout) timeout="${2:-1800}"; shift 2 ;;
      --interval) interval="${2:-10}"; shift 2 ;;
      *) die "unknown wait option: $1" ;;
    esac
  done
  [ -n "$pattern" ] || die "wait requires --pattern"
  [ -n "$target" ] || [ -n "$log" ] || die "wait requires --target or --log"

  local deadline matched="" pane
  deadline=$(( $(date +%s) + timeout ))
  while :; do
    matched=""
    if [ -n "$log" ] && [ -f "$log" ]; then
      matched="$(grep -E -m1 "$pattern" "$log" || true)"
    fi
    if [ -z "$matched" ] && [ -n "$target" ]; then
      pane="$(resolve_target "$target")"
      matched="$(tmux capture-pane -p -t "$pane" -S -200 | grep -E -m1 "$pattern" || true)"
    fi
    if [ -n "$matched" ]; then
      printf 'wait: matched: %s\n' "$matched"
      return 0
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      printf 'wait: timeout after %ss without match of %s\n' "$timeout" "$pattern" >&2
      return 1
    fi
    sleep "$interval"
  done
}

cmd_status() {
  local session=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session) session="${2:-}"; shift 2 ;;
      *) die "unknown status option: $1" ;;
    esac
  done
  if [ -n "$session" ]; then
    tmux list-panes -t "$session" -F '#{session_name} #{window_name}.#{pane_index} #{pane_id} #{pane_title} #{pane_current_command} #{pane_current_path}'
    if [ -f "$(alias_file "$session")" ]; then
      printf '\nAliases:\n'
      cat "$(alias_file "$session")"
    fi
  else
    tmux list-panes -a -F '#{session_name} #{window_name}.#{pane_index} #{pane_id} #{pane_title} #{pane_current_command} #{pane_current_path}'
  fi
}

cmd_interrupt() {
  local target=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target) target="${2:-}"; shift 2 ;;
      *) die "unknown interrupt option: $1" ;;
    esac
  done
  [ -n "$target" ] || die "interrupt requires --target"
  tmux send-keys -t "$(resolve_target "$target")" C-c
  printf 'Interrupted %s\n' "$target"
}

cmd_root_request() {
  local session="" cwd="." command=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session) session="${2:-}"; shift 2 ;;
      --cwd) cwd="${2:-.}"; shift 2 ;;
      --command) command="${2:-}"; shift 2 ;;
      *) die "unknown root-request option: $1" ;;
    esac
  done
  [ -n "$session" ] || die "root-request requires --session"
  [ -n "$command" ] || die "root-request requires --command"
  cwd="$(cd "$cwd" && pwd)"
  session="$(sanitize "$session")"

  cat <<EOF
This command needs elevated privileges and may prompt for your password.
I should not run sudo in Claude's opaque shell or suggest in-session ! sudo.

Please approve a visible root tmux session named '$session' for this scoped task.
The command to run inside that root tmux session is:

$command

If approved, start the root tmux session from a real terminal with:

sudo tmux new-session -As $(printf '%q' "$session") -c $(printf '%q' "$cwd")

Attach command after approval: sudo tmux attach -t $(printf '%q' "$session")
EOF
}

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage
  exit 2
fi
shift

case "$cmd" in
  start) cmd_start "$@" ;;
  send) cmd_send "$@" ;;
  capture) cmd_capture "$@" ;;
  status) cmd_status "$@" ;;
  wait) cmd_wait "$@" ;;
  interrupt) cmd_interrupt "$@" ;;
  root-request) cmd_root_request "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; die "unknown command: $cmd" ;;
esac
