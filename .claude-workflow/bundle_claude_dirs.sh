#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/claude-workflow-bundle.zip}"

cd "$ROOT_DIR"
rm -f "$OUTPUT_PATH"
zip -qr "$OUTPUT_PATH" \
  .claude \
  .claude-workflow \
  CLAUDE.md \
  HARNESS_CHECKLIST.md \
  -x '*/__pycache__/*' '*.pyc' '.tmux-control/*'

printf '%s\n' "$OUTPUT_PATH"
