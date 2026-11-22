# 0010. Agents release on the user's word; a tag is created at release only

Status: Proposed (2026-11-22)
Covers: `.claude/skills/shipping-and-launch/`, `CLAUDE.md` (Isolation and gates), `.claude/skills/dev-flow/SKILL.md` (Step 9, CI checks), `.claude/policy/OPERATING_SPEC.md` (§1, §7)
PR: pending

## Context

The harness stopped at merge: `dev-flow` said a stable release is published on purpose by
the user, and that CI creates a git tag on every merge. No repo has that CI job, and no repo
has a tag or a release. The user wants agents able to ship and launch themselves, given
permission, with one hard requirement: never rebase.

## Decision

- A release is the fifth thing that needs the user's word (`CLAUDE.md`, Isolation and
  gates). The agent proposes it with its pre-release checks, draft notes and rollback plan,
  ends its turn, and on the user's word ships it and runs the post-release check.
- `.claude/skills/shipping-and-launch/` holds the technique. It is copied from
  `addyosmani/agent-skills` (commit `8c99fa3`) and amended in place, like the vendored
  superpowers skills; the amendments are listed in `OPERATING_SPEC.md` §7.
- Release targets, the one variation axis: code, as an annotated git tag and a GitHub
  Release; and a prov artifact, as the label `kind:name@release` moved to a published alias
  version, with the registry pushed. A package index is not built.
- A tag is created at release only, so a tag means released: `v<version>` in a
  single-version repo, `<package>-v<version>` in a multi-package one.
- A rollback never deletes or moves a tag and never repoints an alias version. Code: the
  Release is marked withdrawn and the fix lands by a squash-merged revert or fix PR. prov:
  the label moves back. The agent rolls back at once on a trigger agreed in the proposal;
  otherwise it asks.
- Only tags and the registry are pushed by a release. Never rebase, never force-push.
- A feature flag is a registered deviation (code stance rule 6) whose exit condition is
  full rollout with the flag and the old path removed.

## Consequences

- Easier: a release is one confirmed proposal, and its record is the tag, the Release notes
  and the label history.
- Harder: merged but unreleased versions have no tag; downstream pins them by commit SHA.
- An upstream update of the skill means re-applying the amendments.

## Enforced by

`.claude/verify_setup.sh` checks the skill's file and frontmatter, that `CLAUDE.md` names
the release gate among five, that `dev-flow` no longer has CI tag on merge, and that the
skill has no `git revert ... && git push`. The gate itself, and what is pushed, have only
the user's review and the `git push` entry on the permissions `ask` list.
