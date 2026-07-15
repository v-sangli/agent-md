#!/usr/bin/env bash
set -euo pipefail

state_dir="${TMUX_CONTROL_STATE_DIR:-.tmux-control}"

usage() {
  cat <<'EOF'
Usage:
  tmux_control.sh start --session NAME [--root DIR] [--roles a,b,c] [--replace]
  tmux_control.sh send --target SESSION::ALIAS --command COMMAND [--no-enter]
  tmux_control.sh run --target SESSION::ALIAS --command COMMAND|- [--timeout SECONDS] [--interval SECONDS] [--label LABEL] [--tail N] [--scrollback N]
  tmux_control.sh capture --target SESSION::ALIAS [--lines N] [--join-wrapped] [--output FILE]
  tmux_control.sh wait-for --target SESSION::ALIAS --pattern ERE [--timeout SECONDS] [--interval SECONDS] [--lines N]
  tmux_control.sh status [--session NAME]
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

cmd_wait_for() {
  local target="" pattern="" timeout=120 interval=2 lines=60
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target) target="${2:-}"; shift 2 ;;
      --pattern) pattern="${2:-}"; shift 2 ;;
      --timeout) timeout="${2:-120}"; shift 2 ;;
      --interval) interval="${2:-2}"; shift 2 ;;
      --lines) lines="${2:-60}"; shift 2 ;;
      *) die "unknown wait-for option: $1" ;;
    esac
  done
  [ -n "$target" ] || die "wait-for requires --target"
  [ -n "$pattern" ] || die "wait-for requires --pattern"
  local pane out waited=0
  pane="$(resolve_target "$target")"
  while :; do
    out="$(tmux capture-pane -p -t "$pane" -S "-$lines")"
    if printf '%s\n' "$out" | grep -Eq "$pattern"; then
      printf '%s\n' "$out"
      return 0
    fi
    if [ "$waited" -ge "$timeout" ]; then
      printf '%s\n' "$out"
      printf 'tmux-control: wait-for timed out after %ss without matching: %s\n' "$timeout" "$pattern" >&2
      return 1
    fi
    sleep "$interval"
    waited=$((waited + interval))
  done
}

# run: send + wait-for-completion + scoped capture + exit-code file, one call.
# Replaces the send/sleep-guess/capture and hand-rolled sentinel-poll patterns.
# The payload is written to a runfile and *sourced* in the pane shell, so env
# changes made by the payload (e.g. conda activate) persist for later runs.
# Multi-line payloads are fine: pass --command - and pipe them on stdin.
# Exit code: the payload's own (last command), or 124 on timeout.
cmd_run() {
  local target="" command="" timeout=300 interval=2 label="" tail_n=40 scrollback=5000
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target) target="${2:-}"; shift 2 ;;
      --command) command="${2:-}"; shift 2 ;;
      --timeout) timeout="${2:-300}"; shift 2 ;;
      --interval) interval="${2:-2}"; shift 2 ;;
      --label) label="${2:-}"; shift 2 ;;
      --tail) tail_n="${2:-40}"; shift 2 ;;
      --scrollback) scrollback="${2:-5000}"; shift 2 ;;
      *) die "unknown run option: $1" ;;
    esac
  done
  [ -n "$target" ] || die "run requires --target"
  [ -n "$command" ] || die "run requires --command (use '-' to read stdin)"
  if [ "$command" = "-" ]; then
    command="$(cat)"
    [ -n "$command" ] || die "run: empty command on stdin"
  fi
  [ -n "$label" ] || label="$(printf '%s' "$command" | head -n1 | awk '{print $1}')"
  label="$(sanitize "${label:-run}")"

  local pane id ts run_dir cap_dir runfile logfile ecfile
  pane="$(resolve_target "$target")"
  ts="$(date +%Y%m%dT%H%M%S)"
  id="${ts}_$$"
  run_dir="$state_dir/runs"
  cap_dir="$state_dir/captures"
  mkdir -p "$run_dir" "$cap_dir"
  runfile="$run_dir/$id-$label.sh"
  logfile="$cap_dir/$ts-$label.log"
  ecfile="$cap_dir/$ts-$label.ec"
  printf '%s\n' "$command" >"$runfile"

  # BEGIN/DONE markers bracket exactly this run's output. The typed line
  # splits each marker across two quoted strings so the echoed command line
  # can never match the anchored patterns below.
  local begin="===TC_RUN_BEGIN_$id===" done_pat="===TC_RUN_DONE_$id"
  send_keys "$pane" "printf '===TC_RUN_''BEGIN_$id===\\n'; . $(printf '%q' "$runfile"); printf '===TC_RUN_''DONE_$id ec=%d===\\n' \"\$?\""

  local waited=0 out slice ec=""
  while :; do
    out="$(tmux capture-pane -p -t "$pane" -S "-$scrollback")"
    ec="$(printf '%s\n' "$out" | grep -E "^${done_pat} ec=[0-9]+===\$" | tail -n1 | sed -E 's/.* ec=([0-9]+)===$/\1/')" || true
    [ -n "$ec" ] && break
    if [ "$waited" -ge "$timeout" ]; then
      slice="$(printf '%s\n' "$out" | awk -v b="^${begin}\$" 'found { print } $0 ~ b { found=1 }')"
      printf '%s\n' "$slice" >"$logfile"
      printf 'timeout\n' >"$ecfile"
      printf 'tmux-control: run timed out after %ss (command still in pane; interrupt or wait-for manually)\n' "$timeout" >&2
      printf 'capture: %s\n' "$logfile"
      printf '%s\n' "$slice" | tail -n "$tail_n"
      return 124
    fi
    sleep "$interval"
    waited=$((waited + interval))
  done

  slice="$(printf '%s\n' "$out" | awk -v b="^${begin}\$" -v d="^${done_pat} " '$0 ~ d { exit } found { print } $0 ~ b { found=1 }')"
  printf '%s\n' "$slice" >"$logfile"
  printf '%s\n' "$ec" >"$ecfile"
  printf 'exit=%s capture=%s\n' "$ec" "$logfile"
  printf '%s\n' "$slice" | tail -n "$tail_n"
  return "$ec"
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
  run) cmd_run "$@" ;;
  capture) cmd_capture "$@" ;;
  wait-for) cmd_wait_for "$@" ;;
  status) cmd_status "$@" ;;
  interrupt) cmd_interrupt "$@" ;;
  root-request) cmd_root_request "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; die "unknown command: $cmd" ;;
esac
