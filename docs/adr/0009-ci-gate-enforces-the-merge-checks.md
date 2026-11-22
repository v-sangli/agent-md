# 0009. A CI gate enforces the dev-flow merge checks

Status: Accepted (2026-11-22)
Covers: `scripts/pr_gate.py`, `.github/workflows/verify.yml`, `DEVIATIONS.md`, `.claude/policy/OPERATING_SPEC.md` (`Version:`)
PR: https://github.com/v-sangli/agent-md/pull/2

## Context

ADR 0008 put the verifier in CI and left the dev-flow merge checks to review: unique ADR
numbers, deviations matching their registry, branch-only files deleted, a version raised on
every merge.

## Decision

- `scripts/pr_gate.py` (standard library only) runs as the CI job `gate`, required on `main`
  beside `verify`.
- Always: ADR numbers under `docs/adr/` are unique; `DEVIATION(<id>)` comments and
  `DEVIATIONS.md` rows match both ways (`DEVIATIONS.md` now exists, empty).
- On pull requests: `spikes/`, `docs/superpowers/specs/` and `docs/superpowers/plans/` are gone
  from the repo root (the vendored plugin's own docs are not branch files); the harness version,
  the `Version:` line of `OPERATING_SPEC.md`, is raised above the base's; a major bump comes with
  a change under `docs/adr/`.
- The verifier checks that the spec has a `Version:` line, no longer a fixed number.

## Consequences

Every merge raises the harness version. Supersedes the "not yet covered" note of ADR 0008.

## Enforced by

`.github/workflows/verify.yml` (`gate`) and branch protection on `main` (required `verify`, `gate`).
