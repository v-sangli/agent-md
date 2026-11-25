# 0012. Workspace facts live in a user-scoped store, `~/.agent-docs/`

Status: Proposed
Covers: `.claude/skills/agent-docs/`, `CLAUDE.md` (pointers, Conventions › Environment, Workspace boundary), `.claude/settings.json` (`permissions.additionalDirectories`), `.claude/hooks/session_start.sh`, `.claude/verify_setup.sh`, `.claude/ENV.md` (removed), `.claude/PORTABLE_SETUP.md`, `.claude-workflow/README.md`, `.claude/policy/OPERATING_SPEC.md` (§0, §1, §2, §5, §7, §9)
PR: pending

## Context

The facts needed to work with our tools and repos (cluster access and training recipes,
Python environments, device start-up) had one home, `.claude/ENV.md`: one topic, tracked
in a template that is meant to name no machine, with a verifier carve-out to allow it.
Claude Code's auto memory was rejected as the home: it is opaque and not ours to
configure.

A spike (Claude Code 2.1.332, default permission mode) found: agent edits under
`~/.claude/` prompt even with explicit allow rules, while the same rules silence prompts
on another home directory; an `@~/...` import in a project `CLAUDE.md` loads after a
one-time per-workspace approval and reaches subagents; a missing import target, or a
declined approval, fails silently.

## Decision

- Workspace facts live in one user-scoped store, `~/.agent-docs/`: untracked, never
  bundled, no workspace scope. The template ships its contract and no docs.
- A doc is any `*.md` under the root, except `INDEX.md` and dot-paths, in a tree of
  subdirectories by concern. Its path is its identity. Its frontmatter is closed: exactly
  the three lines `---`, `description: <one line>`, `---`. A description never starts a
  word with `@`, which Claude Code would follow as an import.
- `INDEX.md` is generated from the docs' descriptions by
  `.claude/skills/agent-docs/scripts/agent_docs.sh index`, and `check` validates the store
  and the index. The script is the only place a doc is validated.
- `CLAUDE.md` imports `@~/.agent-docs/INDEX.md`, so every session and subagent holds the
  index. The session hook prints `agent_docs.sh check`, so a missing or broken store is
  reported.
- The store holds facts, not rules. Real credentials are pointers; low-stakes values may
  be inline. Nothing enforces this.
- The agent writes a learned fact without asking and reports it in one line; it proposes
  before rewriting or removing existing content. `~/.agent-docs/` is a standing grant in
  the workspace boundary convention.
- `.claude/ENV.md` is removed, with its verifier checks and carve-out. This replaces the
  design in `OPERATING_SPEC.md` §5 and criterion 7.

## Consequences

The template names no machine anywhere; the portability check has no ENV.md exception.
Facts on any topic have one organized home, readable by the user. Each workspace asks
once to allow the external import; if declined, only the session hook's line shows it.
CI cannot see the live store: it tests the script against fixtures, and the hook reports
the live store at each session start. A tool other than Claude Code can read the store,
since it is plain markdown outside `~/.claude`. Every workspace that installs the harness
reads and writes the same store, so the doc grammar and the index format are a contract
across workspaces: changing either needs an ADR and a re-index of the store.

## Enforced by

`.claude/verify_setup.sh`: `agent_docs.sh` against the fixtures under
`.claude/skills/agent-docs/tests/fixtures/` (valid, golden index, each invalid case,
missing root, `index` leaving `INDEX.md` unchanged on failure); the `CLAUDE.md` import
line; `~/.agent-docs` in `additionalDirectories`; `.claude/ENV.md` absent and named by no
tracked file outside the history and branch-only paths; an `agent-docs:` line in the
session hook's output. The agent's write behavior is enforced only by the user's review.
