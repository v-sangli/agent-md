#!/usr/bin/env bash
set -euo pipefail

CTX_BYTES_PER_TOKEN="${CTX_BYTES_PER_TOKEN:-4.1}"

REPO_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
REPO_DIR="$(cd "$REPO_DIR" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../hooks/lib/externalization.sh"

usage() { echo "usage: ctxgauge.sh <composition|perfile|tokens|capsules-by-phase|evictable> <session.jsonl>" >&2; exit 2; }

cmd="${1:-}"; file="${2:-}"
[ -n "$cmd" ] && [ -n "$file" ] && [ -f "$file" ] || usage

composition() {
  jq -s '{
    prose:        ([.[]|select(.type=="assistant")|.message.content[]?|select(.type=="text")|.text|length]|add // 0),
    capsules:     ([.[]|select(.type=="assistant")|.message.content[]?|select(.type=="thinking")|.signature|length]|add // 0),
    tool_inputs:  ([.[]|select(.type=="assistant")|.message.content[]?|select(.type=="tool_use")|.input|tostring|length]|add // 0),
    tool_results: ([.[]|select(.type=="user")|.message.content|if type=="array" then (.[]|select(.type=="tool_result")|.content|tostring|length) else empty end]|add // 0),
    user:         ([.[]|select(.type=="user")|.message.content|if type=="array" then (.[]|select(.type=="text")|.text|length) else empty end]|add // 0)
  }' "$1"
}

perfile() {
  jq -s '
    [ .[]|select(.type=="assistant")|.message.content[]?|select(.type=="tool_use")
      | {path:(.input.file_path // empty), name:.name,
         bytes:( (.input|tostring|length) )} ]
    | map(select(.path!=null))
    | group_by(.path)
    | map({
        path: .[0].path,
        reads:  (map(select(.name=="Read"))|length),
        writes: (map(select(.name=="Write"))|length),
        write_bytes:(map(select(.name=="Write")|.bytes)|add // 0),
        edits:  (map(select(.name=="Edit" or .name=="MultiEdit"))|length),
        edit_bytes:(map(select(.name=="Edit" or .name=="MultiEdit")|.bytes)|add // 0)
      })
    | sort_by(-(.write_bytes + .edit_bytes))
  ' "$1"
}

tokens() {
  local comp bytes
  comp="$(composition "$1")"
  bytes="$(printf '%s' "$comp" | jq '[.prose,.capsules,.tool_inputs,.tool_results,.user]|add')"
  CTX_WINDOW="${CTX_WINDOW:-1000000}"
  jq -n --argjson b "$bytes" --arg bpt "$CTX_BYTES_PER_TOKEN" --argjson w "$CTX_WINDOW" \
    '{context_bytes:$b, est_tokens:(($b/($bpt|tonumber))|floor), window:$w, fraction:((($b/($bpt|tonumber))/$w*1000|floor)/1000)}'
}

capsules_by_phase() {
  jq -s '[.[]|select(.type=="assistant")
          |{ts:((.timestamp//"")[0:13]),
            cap:([.message.content[]?|select(.type=="thinking")|(.signature|length)]|add // 0)}
          |select(.cap>0)]
         |group_by(.ts)|map({(.[0].ts):(map(.cap)|add)})|add // {}' "$1"
}

evictable() {
  local file="$1"
  # superseded payload bytes: for each path, all but the newest write/edit payload.
  local superseded
  superseded="$(perfile "$file" | jq '[.[]|(.write_bytes + .edit_bytes)]|add // 0')"
  # externalized capsule bytes: capsule mass whose phase bucket predates an
  # externalization write to checklist/memory. Conservative proxy: if HARNESS
  # checklist or any memory file mtime is newer than the earliest capsule ts.
  local cap_total ext_paths earliest_ts
  cap_total="$(capsules_by_phase "$file" | jq '[.[]]|add // 0')"
  earliest_ts="$(jq -sr '[.[]|select(.type=="assistant")|.timestamp//empty]|min // ""' "$file")"
  ext_paths=("$REPO_DIR/HARNESS_CHECKLIST.md")
  # include memory dir if present
  local memdir="$HOME/.claude/projects/-data-workspace-dexworkspace/memory"
  [ -d "$memdir" ] && while IFS= read -r f; do ext_paths+=("$f"); done < <(find "$memdir" -name '*.md' 2>/dev/null)
  local ext_cap=0 epoch=0
  if [ -n "$earliest_ts" ]; then
    epoch="$(date -d "$earliest_ts" +%s 2>/dev/null || echo 0)"
    if externalized_since "$epoch" "${ext_paths[@]}"; then ext_cap="$cap_total"; fi
  fi
  local total_bytes; total_bytes=$(( superseded + ext_cap ))
  jq -n --argjson s "$superseded" --argjson c "$ext_cap" --arg bpt "$CTX_BYTES_PER_TOKEN" \
    '{superseded_payload_bytes:$s, externalized_capsule_bytes:$c,
      evictable_tokens: ((($s+$c)/($bpt|tonumber))|floor)}'
}

case "$cmd" in
  composition) composition "$file" ;;
  perfile) perfile "$file" ;;
  tokens) tokens "$file" ;;
  capsules-by-phase) capsules_by_phase "$file" ;;
  evictable) evictable "$file" ;;
  *) usage ;;
esac
