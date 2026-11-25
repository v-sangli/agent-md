# Spike: agent-docs location and loading

Greenlight: 2026-11-24 (user, in conversation).

## Questions

1. Does an agent write into `~/.claude/<dir>/` raise a permission prompt that a write
   elsewhere outside the repo does not?
2. Does an `@~/...` import in a project `CLAUDE.md` load a file outside the repo? Does it
   ask for approval first?
3. Does the imported content reach a subagent?
4. What happens when the imported file is missing: a visible error, or silence?

## Method

- A canary file at `~/.claude/agent-docs-spike/INDEX.md` holds a unique token.
- A scratch project (in the session scratchpad, outside this repo) has a `CLAUDE.md`
  that imports it; a second one imports a missing file.
- A nested interactive `claude` runs in a tmux pane in each scratch project and is asked
  for the token, directly and through a subagent.

## Monkey patches

None.

## Findings

Claude Code 2.1.332, nested interactive session, `--permission-mode default`.

1. **`~/.claude` is a protected folder for edits.** An agent edit to
   `~/.claude/<dir>/` prompts every time, even with `Edit(~/.claude/<dir>/**)` in
   `permissions.allow` and the dir in `additionalDirectories`. The prompt's widest option
   is "allow Claude to edit files in its ~/.claude folder for this session". Reads there
   pass silently under an allow rule. The same rules on `~/<other-dir>/` silence both read
   and edit prompts. (An auto-mode session wrote into `~/.claude/` without a prompt, so
   the cost depends on the user's mode.)
2. **`@~/...` imports in a project `CLAUDE.md` load files outside the repo**, `~` and
   absolute paths alike, after a one-time per-project dialog "Allow external CLAUDE.md
   file imports?" (stored as `hasClaudeMdExternalIncludesApproved` in `~/.claude.json`).
   Declining disables the imports silently.
3. **Imported content reaches subagents**: a `general-purpose` subagent quoted all
   imported tokens without tools.
4. **A missing import target is silent**: no dialog, warning or error; the rest loads.
5. Side finding: a project under Claude Code's temp tree (`/tmp/claude-<uid>/`) loaded no
   `CLAUDE.md` at all, so the first probe there was void and was rerun under `~`.

Consequences for the design: the store lives outside `~/.claude`, under a user-scope path
that a persistent allow rule covers; an `@` import of its index puts the index in every
session and subagent, behind a one-time approval per workspace, and a missing store fails
silently, so the skill's check must report it.
