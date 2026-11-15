# Local rules for this machine

Not part of the harness template. Claude Code loads this file alongside `CLAUDE.md` and
treats it the same way. It holds what is true only here: hosts, paths, repo names. Keep it
out of anything that is published.

## Worktree guard

- `worktree.bgIsolation: "none"` is set in user-scope `~/.claude/settings.json`, so
  background jobs write to real checkouts directly. That is deliberate. It must live at user
  scope because the guard is per-git-repo: this workspace root is not a repo, and each
  subdirectory (`omniteleop`, `dexdata`, `dexstream`, `Isaac-GR00T`, ...) is its own repo
  whose `.claude/settings.json` the agent cannot write once the guard is active.

## Shell command shape, local additions

Applies to subagents and Monitor/watcher commands too.

- GMI cluster: every command goes through one persistent local tmux session
  (`.claude/skills/tmux-control/scripts/tmux_control.sh`; `tmux ls` first, reuse a `gmi-*`
  session). Never one-shot `ssh`/`scp`/`rsync` to `GMICluster`/`gmij`, never retry loops.
  Enforced by `.claude/hooks/gmi_tmux_guard.sh`.
- Keep paths inside `/data/workspace/dexworkspace`, `/home/vsangli/workspace/dexworkspace`,
  or `/home/vsangli/.claude/jobs`. Anything else leaves the sandbox and prompts.
