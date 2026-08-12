# Claude Workflow Tools

This directory holds repo-local workflow maintenance scripts for the Claude setup.

## Files

- `bundle_claude_dirs.sh`: zip the portable Claude workspace setup
- `update_spec_hashes.sh`: regenerate `.claude/spec_hashes.json` for the current lean workspace contract
- `sync_to_repo.sh`: mirror the live harness surface into the `agent-md` template repo (checksum rsync, deletions propagate). Machine-local files are excluded — `settings.local.json`, `spec_hashes.json`, `scheduled_tasks.lock`, `.tmux-control/`. `.claude/ENV.md` does sync and is the one file expected to be rewritten per machine. Preview with `--dry-run`; commit manually after review.

## Bundle Contents

The bundle script includes portable configuration and skills:

- `.claude/`
- `.claude-workflow/`
- `CLAUDE.md`
- `HARNESS_CHECKLIST.md`

`.claude-log/` and `.claude-tools/` are intentionally excluded.
Python cache files are excluded from the archive.

## Usage

```bash
bash .claude-workflow/bundle_claude_dirs.sh
```
