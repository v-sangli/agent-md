#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"; ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
CTXG="$ROOT_DIR/.claude/context/ctxgauge.sh"
CTX_NUDGE_FRACTION="${CTX_NUDGE_FRACTION:-0.55}"

payload="$(cat || true)"
command -v jq >/dev/null 2>&1 || exit 0
tp="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
[ -n "$tp" ] && [ -f "$tp" ] || exit 0
[ -x "$CTXG" ] || exit 0

tok="$("$CTXG" tokens "$tp" 2>/dev/null || echo '{}')"
frac="$(printf '%s' "$tok" | jq -r '.fraction // 0')"
est="$(printf '%s' "$tok" | jq -r '.est_tokens // 0')"
# numeric compare via awk (fraction is decimal)
over="$(awk -v f="$frac" -v t="$CTX_NUDGE_FRACTION" 'BEGIN{print (f+0>=t+0)?1:0}')"
[ "$over" = "1" ] || exit 0

ev="$("$CTXG" evictable "$tp" 2>/dev/null || echo '{}')"
evtok="$(printf '%s' "$ev" | jq -r '.evictable_tokens // 0')"
top_files="$("$CTXG" perfile "$tp" 2>/dev/null | jq -r '[.[range(0;3)]?|.path]|map(select(.!=null))|join(", ")' 2>/dev/null || true)"

cat <<EOF
⚠ CONTEXT GAUGE — ~${est} tokens (${frac} of window); ~${evtok} tokens evictable.
Suggested steered compaction:
  /compact Preserve verbatim: all decisions + current file states + open TODOs. Discard: reasoning narratives, superseded versions of [${top_files}], exploration dead-ends.
(For a hands-free swap instead, see .claude/context/claude-loop.sh.)
EOF
exit 0
