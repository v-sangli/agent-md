# 0002. Rules live in three homes, each stated once

Status: Accepted (2026-11-13, the 3.1 restructure); the 200-line cap superseded by 0006
Covers: `CLAUDE.md`, `.claude/skills/dev-flow/`, `.claude/skills/superpowers/`
PR: none; decided before this repo kept ADRs, recorded from git history

## Context

The harness was reshaped around an agreed design methodology. Rules had spread across
`CLAUDE.md`, `.claude/policy/AGENT_RULES.md` and the skills. `AGENT_RULES.md` was not
auto-loaded, so its rules held only when the agent went and read it. A `CLAUDE.md` block
declared itself an override of any skill, and the superpowers skills each required the
next one.

## Decision

- `CLAUDE.md` holds what binds any code that gets written. It is always in context,
  subagents included (the built-in Explore and Plan agents excepted).
- `.claude/skills/dev-flow/` holds the order of work for a code change.
- The vendored `superpowers` skills hold the technique for one step; their hand-offs
  return to `dev-flow`.
- `AGENT_RULES.md` is folded into `CLAUDE.md` (Conventions), wording kept. Its line "one
  minimal patch before investigation" is dropped: `systematic-debugging` says the opposite
  and prevails.
- The override block goes, together with its "default off" worktree rule and its "do not
  commit unless asked" rule. Nothing is overridden from elsewhere.
- The vendored `dx` plugin is removed.

## Consequences

One place to look for each kind of rule. Every rule that constrains code must fit in
`CLAUDE.md`, so its size is watched.

## Enforced by

`.claude/verify_setup.sh` asserts `AGENT_RULES.md` is absent and caps the length of
`CLAUDE.md`. "Stated once" is enforced only by review.
