# 0007. Harness decisions are recorded as ADRs

Status: Accepted (2026-11-14)
Covers: `docs/adr/`, `.claude/policy/OPERATING_SPEC.md`, `CLAUDE.md`
PR: pending

## Context

After `HARNESS_CHECKLIST.md` was retired (0003), decisions were logged as dated entries in
`OPERATING_SPEC.md`, which turned it into a changelog mixed with the current design.

## Decision

- Each harness decision is an ADR under `docs/adr/`, in the form `dev-flow` describes.
- `OPERATING_SPEC.md` describes the current design and its rationale only, with no dated
  history; it points to the ADRs.
- `docs/adr/` is not bundled with the template, so its numbers never collide with a
  project's own ADRs.

## Consequences

The spec stays short and current; the why and when of each change is one file each.

## Enforced by

`.claude/verify_setup.sh` requires `docs/adr/` and the spec's pointer to it.
