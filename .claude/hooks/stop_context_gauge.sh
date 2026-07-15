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

STATE_DIR="$ROOT_DIR/.claude/context/state"; mkdir -p "$STATE_DIR"
if [ "${CTX_HANDOFF_MODE:-0}" = "1" ]; then
  {
    {
      echo "# Prior-session recap (auto-generated at ~${est} tokens, ${frac} of window)"
      echo "## Preserve"
      echo "- All decisions and current file states (see HARNESS_CHECKLIST.md / memory)."
      echo "- Open TODOs and last verify status."
      echo "## Superseded / dropped"
      echo "- Reasoning narratives; older versions of: ${top_files}."
      echo ""
      echo "> Fallback skeleton. Run the context-handoff skill to overwrite with a curated recap before relying on it."
    } > "$STATE_DIR/recap.md"
    : > "$STATE_DIR/handoff.pending"
  } || true
fi

cat <<EOF
⚠ CONTEXT GAUGE — ~${est} tokens (${frac} of window); ~${evtok} tokens evictable.
Suggested steered compaction:
  /compact Preserve verbatim: all decisions + current file states + open TODOs. Discard: reasoning narratives, superseded versions of [${top_files}], exploration dead-ends.
(Run the context-handoff skill to curate a recap, then /exit — .claude/context/claude-loop.sh will relaunch you with it reseeded.)
EOF
exit 0
