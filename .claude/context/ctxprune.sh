#!/usr/bin/env bash
set -euo pipefail

usage() { echo "usage: ctxprune.sh <validate|prune|clone> <session.jsonl|session-id> [out.jsonl]" >&2; exit 2; }

cmd="${1:-}"; arg="${2:-}"
[ -n "$cmd" ] && [ -n "$arg" ] || usage

validate() {
  local uses results orphans
  if ! jq -e . "$1" >/dev/null 2>&1; then
    echo "ctxprune: malformed JSONL: $1" >&2
    return 1
  fi
  uses="$(jq -r '.message.content[]?|select(.type=="tool_use")|.id' "$1" 2>/dev/null | sort -u)"
  results="$(jq -r '.message.content[]?|select(.type=="tool_result")|.tool_use_id' "$1" 2>/dev/null | sort -u)"
  orphans="$(comm -3 <(printf '%s\n' "$uses") <(printf '%s\n' "$results") | tr -d '\t' | sed '/^$/d')"
  if [ -n "$orphans" ]; then
    echo "PAIRING VIOLATION — unmatched tool_use/tool_result ids:" >&2
    printf '%s\n' "$orphans" >&2
    return 1
  fi
  return 0
}

prune() {
  local in="$1" out="${2:-}"
  [ -n "$out" ] || { echo "prune requires out path" >&2; return 2; }

  if ! jq -e . "$in" >/dev/null 2>&1; then
    echo "ctxprune: malformed JSONL: $in" >&2
    return 1
  fi

  # 1) paths that get a later Write/Edit/MultiEdit -> their earlier Read results are superseded
  local superseded_paths
  superseded_paths="$(jq -rs '
    [ .[]|select(.type=="assistant")|.message.content[]?|select(.type=="tool_use")
      |{path:(.input.file_path//empty),name:.name} ]
    | map(select(.path!=null and .path!=""))
    | group_by(.path)
    | map(select(any(.[]; .name=="Write" or .name=="Edit" or .name=="MultiEdit")))
    | map(.[0].path) | .[]' "$in" 2>/dev/null)"

  local superseded_json
  superseded_json="$(printf '%s\n' "$superseded_paths" | sed '/^$/d' | jq -R . | jq -s .)"

  # 2) tool_use ids of Read calls whose path is superseded -> their results get stubbed
  local stub_ids
  stub_ids="$(jq -rs --argjson sp "$superseded_json" '
    [ .[]|select(.type=="assistant")|.message.content[]?|select(.type=="tool_use" and .name=="Read")
      |select((.input.file_path//"") as $p | ($sp|index($p))!=null)|.id ] | .[]' "$in" 2>/dev/null)"

  # 3) uuid of the last assistant line -> keep only its thinking capsules
  local last_assistant_uuid
  last_assistant_uuid="$(jq -rs '[.[]|select(.type=="assistant" and (.isSidechain != true))]|last|.uuid // ""' "$in" 2>/dev/null)"

  local stub_json
  stub_json="$(printf '%s\n' "$stub_ids" | sed '/^$/d' | jq -R . | jq -s .)"

  jq -c --argjson stub "$stub_json" --arg keepcap "$last_assistant_uuid" '
    # drop prior-turn capsules: remove thinking blocks unless this is the kept last-assistant line
    ( if .type=="assistant" and (.uuid != $keepcap) then
        .message.content |= (if type=="array" then map(select(.type!="thinking")) else . end)
      else . end )
    |
    # stub superseded read results (never drop the tool_result object itself)
    ( if .type=="user" then
        .message.content |= (if type=="array" then
          map( if .type=="tool_result" and ((.tool_use_id) as $id | ($stub|index($id))!=null)
               then .content="[pruned: re-read file]" else . end) else . end)
      else . end )
  ' "$in" > "$out"

  local before after
  before="$(wc -c < "$in")"; after="$(wc -c < "$out")"
  echo "ctxprune: $in ($before B) -> $out ($after B); saved $((before-after)) B" >&2
}

clone() {
  local sid="$1"
  local proj="${CTX_PROJECTS_DIR:-$HOME/.claude/projects/-data-workspace-dexworkspace}"
  local in="$proj/$sid.jsonl"
  [ -f "$in" ] || { echo "no session file: $in" >&2; return 1; }
  # new id: derive deterministically from input hash (no date/random needed)
  local newid
  newid="$(sha1sum "$in" | cut -c1-8)-0000-0000-0000-$(sha1sum "$in" | cut -c9-20)"
  local out="$proj/$newid.jsonl"
  if [ -e "$out" ]; then
    echo "ctxprune: warning: overwriting existing clone output: $out" >&2
  fi
  prune "$in" "$out"
  validate "$out" || { echo "pruned clone failed validation; not resuming" >&2; return 1; }
  echo "Pruned clone ready. Resume with:"
  echo "  claude --resume $newid"
}

case "$cmd" in
  validate)
    [ -f "$arg" ] || { echo "no such file: $arg" >&2; exit 2; }
    validate "$arg"
    ;;
  prune)
    [ -f "$arg" ] || { echo "no such file: $arg" >&2; exit 2; }
    prune "$arg" "${3:-}"
    ;;
  clone)
    clone "$arg"
    ;;
  *) usage ;;
esac
