# Claude Workflow Tools

This directory holds repo-local workflow maintenance scripts for the Claude setup.

## Files

- `bundle_claude_dirs.sh`: zip the portable Claude workspace setup
- `update_spec_hashes.sh`: regenerate `.claude/spec_hashes.json` for the current lean workspace contract

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
