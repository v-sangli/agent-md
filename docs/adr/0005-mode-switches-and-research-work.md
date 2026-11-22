# 0005. Mode switches are the agent's judgement; research work is recorded in prov

Status: Accepted (2026-11-14)
Covers: `CLAUDE.md` (Isolation and gates, Research work), `.claude/skills/dev-flow/SKILL.md`
(Step 1, When to stop)
PR: pending

## Context

Work evolves: an experiment grows into a feature, a fix turns out to be a refactor. The
rules sent every mode switch back to the user, and had nothing on how experiment work is
recorded. The provenance tool (`prov`) keeps a permanent record of every run, dataset and
finding on the machine, whatever becomes of a branch.

## Decision

- Switching mode mid-work, or handing work between `exp/` and another branch, is the
  agent's judgement. The agent records the switch and its reason on the branch, and the
  new mode's gates apply.
- Experiment work lives on an `exp/` branch and is recorded with `prov` and the skills it
  installs. The agent reads the journal's `NOW.md` first. A finding cites the IDs it rests
  on.
- A feature, fix or refactor an experiment needs goes on its own branch through
  `dev-flow`; it may start from the `exp/` branch and return to it by PR (0004).

Unchanged: an `exp/` branch still needs the user's go-ahead, and a design gap still stops
the work and goes back to the user.

## Consequences

The trace of work is the branch history plus the provenance records, not a sequence of
approvals. `CLAUDE.md` now names `prov`, a tool rather than a host, path or repo.

## Enforced by

Nothing mechanical; the user's review.
