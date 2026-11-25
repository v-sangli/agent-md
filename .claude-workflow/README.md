# Claude Workflow Tools

This directory holds repo-local workflow maintenance scripts for the Claude setup.

## Files

- `bundle_claude_dirs.sh`: zip the portable Claude workspace setup
- `update_spec_hashes.sh`: regenerate `.claude/spec_hashes.json` for the current lean workspace contract
- `install_prov.sh <ref>`: install prov once per machine from one clone at a release tag: its venv, CLI and skill links, and the pointer file session start reads (ADR 0011)
- `sync_to_repo.sh`: mirror the live harness surface into the `agent-md` template repo (checksum rsync, deletions propagate). Machine-local files are excluded — `settings.local.json`, `spec_hashes.json`, `scheduled_tasks.lock`. Nothing synced is machine-specific: workspace facts live in `~/.agent-docs/`, outside the repo. Preview with `--dry-run`; commit manually after review.

## Bundle Contents

The bundle script includes portable configuration and skills:

- `.claude/`
- `.claude-workflow/`
- `CLAUDE.md`

`.claude-log/` and `.claude-tools/` are intentionally excluded.
Python cache files are excluded from the archive.

## Usage

```bash
bash .claude-workflow/bundle_claude_dirs.sh
```
