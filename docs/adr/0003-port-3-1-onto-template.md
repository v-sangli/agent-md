# 0003. The 3.1 restructure is ported onto the template

Status: Accepted (2026-11-14)
Covers: `CLAUDE.md`, `.claude/skills/tmux-control/`, `.claude/hooks/session_end.sh`,
`.claude/skills/superpowers/skills/subagent-driven-development/`
PR: none; decided before this repo kept ADRs, recorded from git history

## Context

The 3.1 restructure (0002) was written on another machine, on top of that machine's copy of
the harness, which predated the template's 2026-11-09 changes. The two disagreed in places.

## Decision

- Isolation and gates (worktrees by default, commits on the feature branch) come from 3.1.
- tmux comes from the template: the root session is user-owned and escalated in-pane with
  `sudo -i`, not a shared `sudo tmux -S` socket whose server is root-owned. Sessions carry
  `@claude_session` and `@role` pane options. `stop`, `cleanup` and the `SessionEnd` hook
  (`cleanup --idle-only`) reap only the calling session's own sessions.
- Every subagent runs on opus, stated in `CLAUDE.md` and in the vendored
  `subagent-driven-development` skill (from 2026-11-09); models are not tiered by
  difficulty.
- The other machine's GMI guard hook and its `CLAUDE.local.md` stay on that machine.
  `CLAUDE.local.md` is git-ignored here.
- `HARNESS_CHECKLIST.md` is retired; its entries stay in git history. Superseded in part
  by 0007 for where decisions are now recorded.

## Consequences

One template carries both lines of work. Machine-specific rules have a home outside it.

## Enforced by

`.claude/verify_setup.sh`: the tmux root-request and cleanup checks.
