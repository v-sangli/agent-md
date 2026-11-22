# 0008. CI runs the harness verifier on every PR

Status: Accepted (2026-11-21); "not yet covered" checks covered by 0009
Covers: `.github/workflows/verify.yml`, `.claude/verify_setup.sh`
PR: https://github.com/v-sangli/agent-md/pull/1

## Context

`main` changes only by a squash-merged PR with green CI, but the repo had no CI: the
verifier ran only when someone remembered to run it.

## Decision

- A GitHub Actions workflow runs `bash .claude/verify_setup.sh` on every pull request and
  on every push to `main`, on a clean Ubuntu runner.
- The verifier stays the single check; CI adds no checks of its own.

Not yet covered: the other checks `dev-flow` lists (version raised, branch-only files
gone, ADR numbers unique, deviations match). Until they exist, the user's review enforces
those rules.

## Consequences

A PR whose verifier fails shows red. Branch protection on `main` is a repo setting, made
by the user, not by this file.

## Enforced by

`.github/workflows/verify.yml`.
