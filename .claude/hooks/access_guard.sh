#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
CONFIG_PATH="$ROOT_DIR/.claude/access.conf"

payload="$(cat || true)"
if [ -z "$payload" ] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || true)"
[ -n "$tool_name" ] || exit 0

config_value() {
  local key="$1" default="$2" line value
  [ -f "$CONFIG_PATH" ] || {
    printf '%s\n' "$default"
    return
  }
  line="$(grep -E "^[[:space:]]*${key}=" "$CONFIG_PATH" | tail -n 1 || true)"
  [ -n "$line" ] || {
    printf '%s\n' "$default"
    return
  }
  value="${line#*=}"
  value="${value%%#*}"
  printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

is_true() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

ALLOW_EXTERNAL_WRITE="$(config_value allow_external_write false)"
ALLOW_EXTERNAL_DELETE="$(config_value allow_external_delete false)"
EXTERNAL_WRITE_ROOTS="$(config_value external_write_roots "")"
EXTERNAL_DELETE_ROOTS="$(config_value external_delete_roots "")"
MAINTAINER_MODE="$(config_value maintainer_mode false)"

severity_rank() {
  case "$1" in
    ok) printf '0\n' ;;
    ask) printf '1\n' ;;
    critical) printf '2\n' ;;
    *) printf '0\n' ;;
  esac
}

max_severity="ok"
findings=()
action_count=0

is_under() {
  local path="$1" base="$2"
  [[ "$path" == "$base" || "$path" == "$base/"* ]]
}

clean_raw_path() {
  local raw="$1"
  raw="${raw%$'\r'}"
  raw="${raw%$'\n'}"
  raw="${raw#\"}"
  raw="${raw%\"}"
  raw="${raw#\'}"
  raw="${raw%\'}"
  printf '%s\n' "$raw"
}

resolve_path() {
  local raw="$1" path
  raw="$(clean_raw_path "$raw")"
  [ -n "$raw" ] || return 1

  case "$raw" in
    -|--|--*) return 1 ;;
  esac

  if [[ "$raw" == *'$'* || "$raw" == *'`'* || "$raw" == *'{'* || "$raw" == *'}'* ]]; then
    printf 'UNKNOWN:%s\n' "$raw"
    return 0
  fi

  case "$raw" in
    "~") path="$HOME" ;;
    "~/"*) path="$HOME/${raw#~/}" ;;
    /*) path="$raw" ;;
    *) path="$ROOT_DIR/$raw" ;;
  esac

  realpath -m -- "$path" 2>/dev/null || printf '%s\n' "$path"
}

root_allowed_by_list() {
  local path="$1" roots="$2" root
  [ -n "$roots" ] || return 0
  IFS=':' read -r -a root_list <<<"$roots"
  for root in "${root_list[@]}"; do
    [ -n "$root" ] || continue
    case "$root" in
      "~") root="$HOME" ;;
      "~/"*) root="$HOME/${root#~/}" ;;
      /*) ;;
      *) root="$ROOT_DIR/$root" ;;
    esac
    root="$(realpath -m -- "$root" 2>/dev/null || printf '%s\n' "$root")"
    if is_under "$path" "$root"; then
      return 0
    fi
  done
  return 1
}

record_finding() {
  local level="$1" op="$2" raw="$3" resolved="$4" note="$5"
  local current_rank new_rank
  current_rank="$(severity_rank "$max_severity")"
  new_rank="$(severity_rank "$level")"
  if [ "$new_rank" -gt "$current_rank" ]; then
    max_severity="$level"
  fi
  findings+=("$level"$'\t'"$op"$'\t'"$raw"$'\t'"$resolved"$'\t'"$note")
}

classify_target() {
  local op="$1" raw="$2" resolved level note flag roots
  raw="$(clean_raw_path "$raw")"
  [ -n "$raw" ] || return 0
  case "$raw" in
    -|--|--*) return 0 ;;
  esac

  action_count=$((action_count + 1))
  resolved="$(resolve_path "$raw" || true)"
  if [[ "$resolved" == UNKNOWN:* ]]; then
    record_finding ask "$op" "$raw" "$resolved" "dynamic or unresolved path"
    return 0
  fi

  if [ "$resolved" = "/dev/null" ]; then
    record_finding ok "$op" "$raw" "$resolved" "null sink"
    return 0
  fi

  level="ask"
  note="external path requires approval"

  if [ "$resolved" = "/" ]; then
    level="critical"
    note="filesystem root"
  elif [ "$op" = "delete" ] && [ "$resolved" = "$ROOT_DIR" ]; then
    level="critical"
    note="workspace root"
  elif [ "$op" = "delete" ] && [ "$resolved" = "/tmp" ]; then
    level="critical"
    note="/tmp root"
  elif [ "$resolved" = "$HOME" ]; then
    level="critical"
    note="home directory root"
  elif is_under "$resolved" "/etc" || is_under "$resolved" "/usr" || is_under "$resolved" "/var" || \
       is_under "$resolved" "/boot" || is_under "$resolved" "/dev" || is_under "$resolved" "/proc" || \
       is_under "$resolved" "/sys"; then
    level="critical"
    note="system path"
  elif is_under "$resolved" "$ROOT_DIR/.claude"; then
    if is_true "$MAINTAINER_MODE"; then
      level="ok"
      note="maintainer-mode .claude path"
    else
      level="critical"
      note="protected .claude path"
    fi
  elif is_under "$resolved" "$ROOT_DIR/.git"; then
    level="critical"
    note="protected .git path"
  elif is_under "$resolved" "$ROOT_DIR"; then
    level="ok"
    note="workspace path"
  elif is_under "$resolved" "/tmp"; then
    level="ok"
    note="/tmp content path"
  else
    if [ "$op" = "delete" ]; then
      flag="$ALLOW_EXTERNAL_DELETE"
      roots="$EXTERNAL_DELETE_ROOTS"
    else
      flag="$ALLOW_EXTERNAL_WRITE"
      roots="$EXTERNAL_WRITE_ROOTS"
    fi
    if is_true "$flag" && root_allowed_by_list "$resolved" "$roots"; then
      level="ok"
      note="external ${op} grant"
    fi
  fi

  record_finding "$level" "$op" "$raw" "$resolved" "$note"
}

is_separator() {
  case "$1" in
    ';'|'&&'|'||'|'|'|'('|')') return 0 ;;
    *) return 1 ;;
  esac
}

tokenize_command() {
  local input="$1" len i ch next token quote escape
  len="${#input}"
  token=""
  quote=""
  escape=0

  for ((i = 0; i < len; i++)); do
    ch="${input:i:1}"
    if [ "$escape" -eq 1 ]; then
      token+="$ch"
      escape=0
      continue
    fi

    if [ -n "$quote" ]; then
      if [ "$ch" = "\\" ] && [ "$quote" = '"' ]; then
        escape=1
      elif [ "$ch" = "$quote" ]; then
        quote=""
      else
        token+="$ch"
      fi
      continue
    fi

    case "$ch" in
      "'"|'"') quote="$ch" ;;
      "\\") escape=1 ;;
      $' '|$'\t'|$'\r'|$'\n')
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        ;;
      ';'|'('|')')
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        printf '%s\n' "$ch"
        ;;
      '&')
        next="${input:i+1:1}"
        if [ "$next" = "&" ]; then
          if [ -n "$token" ]; then
            printf '%s\n' "$token"
            token=""
          fi
          printf '&&\n'
          i=$((i + 1))
        elif [ "$next" = ">" ]; then
          if [ -n "$token" ]; then
            printf '%s\n' "$token"
            token=""
          fi
          printf '&>\n'
          i=$((i + 1))
        else
          token+="$ch"
        fi
        ;;
      '|')
        next="${input:i+1:1}"
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        if [ "$next" = "|" ]; then
          printf '||\n'
          i=$((i + 1))
        else
          printf '|\n'
        fi
        ;;
      '>')
        next="${input:i+1:1}"
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        if [ "$next" = ">" ]; then
          printf '>>\n'
          i=$((i + 1))
        else
          printf '>\n'
        fi
        ;;
      *) token+="$ch" ;;
    esac
  done

  if [ -n "$token" ]; then
    printf '%s\n' "$token"
  fi
}

next_segment_tokens() {
  local start="$1" j token
  segment=()
  for ((j = start; j < ${#tokens[@]}; j++)); do
    token="${tokens[$j]}"
    is_separator "$token" && break
    segment+=("$token")
  done
}

scan_rm_like() {
  local i="$1" j token
  for ((j = i + 1; j < ${#tokens[@]}; j++)); do
    token="${tokens[$j]}"
    is_separator "$token" && break
    case "$token" in
      --) continue ;;
      -*) continue ;;
    esac
    classify_target delete "$token"
  done
}

scan_all_operands_as_write() {
  local i="$1" j token
  for ((j = i + 1; j < ${#tokens[@]}; j++)); do
    token="${tokens[$j]}"
    is_separator "$token" && break
    case "$token" in
      --) continue ;;
      -*) continue ;;
    esac
    classify_target write "$token"
  done
}

scan_cp() {
  local i="$1" j token last=""
  for ((j = i + 1; j < ${#tokens[@]}; j++)); do
    token="${tokens[$j]}"
    is_separator "$token" && break
    case "$token" in
      --) continue ;;
      -*) continue ;;
    esac
    last="$token"
  done
  [ -n "$last" ] && classify_target write "$last"
}

scan_mv() {
  local i="$1" j token operands=()
  for ((j = i + 1; j < ${#tokens[@]}; j++)); do
    token="${tokens[$j]}"
    is_separator "$token" && break
    case "$token" in
      --) continue ;;
      -*) continue ;;
    esac
    operands+=("$token")
  done
  [ "${#operands[@]}" -eq 0 ] && return 0
  for ((j = 0; j < ${#operands[@]}; j++)); do
    if [ "$j" -eq $((${#operands[@]} - 1)) ]; then
      classify_target write "${operands[$j]}"
    else
      classify_target delete "${operands[$j]}"
    fi
  done
}

scan_sed() {
  local i="$1" j token inplace=0 operands=() skip_next=0
  for ((j = i + 1; j < ${#tokens[@]}; j++)); do
    token="${tokens[$j]}"
    is_separator "$token" && break
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi
    case "$token" in
      -i|-i*) inplace=1; continue ;;
      -e|-f) skip_next=1; continue ;;
      -*) continue ;;
    esac
    operands+=("$token")
  done
  [ "$inplace" -eq 1 ] || return 0
  if [ "${#operands[@]}" -gt 1 ]; then
    for ((j = 1; j < ${#operands[@]}; j++)); do
      classify_target write "${operands[$j]}"
    done
  fi
}

scan_perl() {
  local i="$1" j token inplace=0 skip_next=0
  for ((j = i + 1; j < ${#tokens[@]}; j++)); do
    token="${tokens[$j]}"
    is_separator "$token" && break
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi
    case "$token" in
      -pi|-pi*|-i|-i*) inplace=1; continue ;;
      -e) skip_next=1; continue ;;
      -*) continue ;;
    esac
    [ "$inplace" -eq 1 ] && classify_target write "$token"
  done
}

scan_tokens() {
  local i token next
  for ((i = 0; i < ${#tokens[@]}; i++)); do
    token="${tokens[$i]}"
    case "$token" in
      '>'|'>>'|'&>')
        next="${tokens[$((i + 1))]:-}"
        if [ -n "$next" ] && ! is_separator "$next" && [[ "$next" != '&'* ]]; then
          classify_target write "$next"
        fi
        ;;
      rm|rmdir) scan_rm_like "$i" ;;
      mkdir|touch|truncate|chmod|chown|install|tee) scan_all_operands_as_write "$i" ;;
      cp) scan_cp "$i" ;;
      mv) scan_mv "$i" ;;
      sed) scan_sed "$i" ;;
      perl) scan_perl "$i" ;;
    esac
  done
}

emit_decision() {
  local level="$1" decision="$2" reason="$3"
  jq -n --arg level "$level" --arg decision "$decision" --arg reason "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",accessLevel:$level,permissionDecision:$decision,permissionDecisionReason:$reason}}'
}

build_reason() {
  local level="$1" heading item shown=0 sev op raw resolved note prefix
  case "$level" in
    ok) heading="Access guard: write/delete targets stay within the workspace or safe /tmp content." ;;
    ask) heading="Access guard: this command writes/deletes outside the workspace or safe /tmp content." ;;
    critical) heading="CRITICAL access guard: this command targets protected or high-risk paths. Review carefully before allowing." ;;
    *) heading="Access guard decision." ;;
  esac
  printf '%s\n' "$heading"
  for item in "${findings[@]}"; do
    IFS=$'\t' read -r sev op raw resolved note <<<"$item"
    [ "$level" = "ok" ] || [ "$sev" != "ok" ] || continue
    prefix="-"
    [ "$sev" = "critical" ] && prefix="- CRITICAL:"
    [ "$sev" = "ask" ] && prefix="- ASK:"
    printf '%s %s `%s` -> `%s` (%s)\n' "$prefix" "$op" "$raw" "$resolved" "$note"
    shown=$((shown + 1))
    [ "$shown" -ge 8 ] && break
  done
}

handle_write_tool() {
  local path
  path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
  [ -n "$path" ] || exit 0
  classify_target write "$path"
}

handle_bash_tool() {
  local command
  command="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
  [ -n "$command" ] || exit 0

  mapfile -t tokens < <(tokenize_command "$command")
  [ "${#tokens[@]}" -gt 0 ] || exit 0
  scan_tokens
}

case "$tool_name" in
  Bash) handle_bash_tool ;;
  Edit|Write|MultiEdit) handle_write_tool ;;
  *) exit 0 ;;
esac

[ "$action_count" -gt 0 ] || exit 0

case "$max_severity" in
  ok) emit_decision ok allow "$(build_reason ok)" ;;
  ask) emit_decision ask ask "$(build_reason ask)" ;;
  critical) emit_decision critical ask "$(build_reason critical)" ;;
esac
