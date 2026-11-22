# 0001. Enforcement is advisory: no tool call is blocked

Status: Accepted (2026-07-26; old files deleted 2026-08-12)
Covers: `.claude/settings.json`, `.claude/hooks/`, `CLAUDE.md` (Conventions)
PR: none; decided before this repo kept ADRs, recorded from git history

## Context

Up to version 2.1 the harness enforced its contract with blocking PreToolUse/PostToolUse
hooks (`access_guard.sh`, `pre_tool_use_guard.sh`, `pre_tool_use_bash_guard.sh`,
`post_tool_use_privilege_guard.sh`), a shell-write executor (`.claude/harness/run.sh`) and
`.claude/access.conf`.

- Hook commands were registered with relative paths and ran in the session's current
  working directory. When the shell's cwd drifted out of the workspace, every hook failed
  non-blocking: enforcement silently vanished while tools kept running.
- Working around it put machine-specific absolute paths into `settings.json` and the
  permission rules, which defeated portability.
- The prompt/block friction outweighed the protection: the model's actual failure modes
  were path/cwd bugs, not destructive intent.

## Decision

- `CLAUDE.md` states conventions; no hook blocks a tool call.
- Claude Code's native permission `ask` list carries the few dangerous operations:
  `git push`, `git reset --hard`, `sudo`. Everything else is allowed.
- `tmux-control` is the encouraged route for visible and long-running work, not a gate.
- Mechanical checks belong to each repo's CI and branch protection, not to hooks here.

## Consequences

Nothing fails silently any more, and the template stays free of machine paths. A rule now
holds only as far as the agent follows the text, or a repo's CI checks it.

## Enforced by

`.claude/verify_setup.sh`: the removed hook files, `run.sh` and `access.conf` are absent;
`settings.json` registers no blocking hook and has no absolute paths; the three `ask`
entries are present.
