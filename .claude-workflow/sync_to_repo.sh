#!/usr/bin/env bash
set -euo pipefail

# Mirror the live harness surface into the agent-md template repo.
# Live tree is the source of truth: changes AND deletions propagate.
# Machine-local files are excluded so grants/approvals never leak into
# the template. Commit is left to the operator — this script only syncs
# and reports.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REPO_DIR="$ROOT_DIR/agent-md"
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO_DIR="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) printf 'usage: sync_to_repo.sh [--repo DIR] [--dry-run]\n' >&2; exit 2 ;;
  esac
done

[ -d "$REPO_DIR/.git" ] || { printf 'sync_to_repo: %s is not a git repo\n' "$REPO_DIR" >&2; exit 2; }

# Machine-local: never sync (repo keeps its committed safe defaults).
EXCLUDES=(
  --exclude 'spec_hashes.json'
  --exclude 'settings.local.json'
  --exclude 'access.conf'
  --exclude '__pycache__/'
  --exclude '*.pyc'
)

# --checksum: the original repo->workspace copy did not preserve mtimes, so
# timestamp comparison flags hundreds of identical files; compare content.
RSYNC_FLAGS=(-a --checksum --delete)
[ "$DRY_RUN" = "1" ] && RSYNC_FLAGS+=(-n -v)

rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$ROOT_DIR/.claude/" "$REPO_DIR/.claude/"
rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$ROOT_DIR/.claude-workflow/" "$REPO_DIR/.claude-workflow/"
if [ "$DRY_RUN" = "0" ]; then
  cp -p "$ROOT_DIR/CLAUDE.md" "$ROOT_DIR/HARNESS_CHECKLIST.md" "$REPO_DIR/"
fi

if [ "$DRY_RUN" = "1" ]; then
  printf '\nsync_to_repo: DRY RUN — nothing written.\n'
  exit 0
fi

printf '\n=== repo status after sync ===\n'
git -C "$REPO_DIR" status -s
printf '\n=== diffstat vs HEAD ===\n'
git -C "$REPO_DIR" diff --stat
printf '\nsync_to_repo: done. Review above, then commit in %s\n' "$REPO_DIR"
