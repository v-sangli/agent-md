# 0004. A feature branch need not start from `main`

Status: Accepted (2026-11-14)
Covers: `CLAUDE.md` (Isolation and gates), `.claude/skills/dev-flow/SKILL.md` (Step 2)
PR: pending

## Context

`CLAUDE.md` and `dev-flow` said a feature branch lives in a worktree off `main`. What the
rules need is isolation between features, so the work can be tracked. Requiring `main` as
the base forced, for example, a feature an experiment needs to go out to `main` and back.

## Decision

One feature per branch, each in its own worktree, returning by PR. The branch may start
from whatever branch the work belongs to.

## Consequences

A feature can be built for an `exp/` branch and returned to it. `main` still changes only
by a squash-merged PR with green CI.

## Enforced by

Nothing mechanical; the user's review.
