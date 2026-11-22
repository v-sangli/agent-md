# 0006. `CLAUDE.md` is capped at 300 lines

Status: Accepted (2026-11-14); supersedes the 200-line cap of 0002
Covers: `CLAUDE.md`, `.claude/verify_setup.sh`
PR: pending

## Context

The 200-line cap was arbitrary, and the Research work section (0005) did not fit under it.

## Decision

`CLAUDE.md` stays under 300 lines. The cap keeps its growth deliberate.

## Consequences

Room for what binds code; growth past 300 still has to be paid for by moving text out.

## Enforced by

`.claude/verify_setup.sh` fails at 300 lines or more.
