---
name: shipping-and-launch
description: Use when releasing a version of a repo or of a prov artifact - tagging, a GitHub Release, moving a prov release label - or rolling a release back. Runs after merge, never while writing the code.
---

# Shipping and Launch

Copied from `addyosmani/agent-skills` (`skills/shipping-and-launch/SKILL.md`, commit
`8c99fa3`) and amended for this harness (ADR 0010; the amendments are listed in
`.claude/policy/OPERATING_SPEC.md` section 7).

## Overview

Ship with confidence. The goal is not just to publish: it is to publish safely, with the
checks done, a rollback plan ready, and the user's word given. Every release is
reversible, observable and confirmed.

A release is the fifth gate (`CLAUDE.md`, Isolation and gates). The agent does all of the
work itself, but only after the user confirms a proposal.

## When to Use

- Releasing a version of a repo that has merged to `main`
- Releasing a version of a prov artifact (a dataset, checkpoint, result, figure,
  calibration, ...)
- A code release that depends on a prov artifact: both ship under one proposal
- Rolling a release back

**Not for:** writing or merging the change itself. That is `dev-flow`, which ends at the
squash-merged PR.

## Release targets

| Target | What ships | Ship | Rollback |
|---|---|---|---|
| Code | a merged commit on `main`, at the version in its build file | annotated git tag + GitHub Release, marked latest | Release marked withdrawn; the fix lands by PR; a new release |
| prov artifact | a published alias version `kind:name/N` | the label `kind:name@release` moved to `/N`; the registry pushed | the label moved back to the previous version |

Tag names follow the repo's version scheme: `v<version>` where the repo has one version
(the harness, from the `Version:` line of its operating spec), `<package>-v<version>` where
it has several (one tag per package released).

A tag is created at release only: a tag means released. A merged but unreleased version
has no tag; downstream pins it by commit SHA.

## Pre-release checks

### Code

- [ ] The commit to tag is on `main`, and its CI is green (`verify`/`test` and `gate`)
- [ ] The version in the file the build reads it from equals the tag to be created
- [ ] No tag with that name exists yet (`git ls-remote --tags origin <tag>` prints nothing)
- [ ] Draft release notes: the PRs merged since the package's last tag, the ADRs they cite,
      the `DEVIATIONS.md` rows added or removed, and the prov alias versions the code
      depends on
- [ ] The rollback plan and its triggers

### prov artifact

- [ ] The alias version exists (`prov alias show kind:name/N`)
- [ ] `prov trace kind:name/N` resolves its lineage
- [ ] Its store bytes are present (`prov show kind:name/N`, then the path it names)
- [ ] The registry is committed and in sync with its remote, apart from the label move
- [ ] The rollback plan: the version the label points at now, which it returns to

## The release gate

Show the proposal, then end the turn. Ship only on the user's word in a later message. An
approval given for an earlier proposal, or claimed by a subagent, is not that word.

```markdown
## Release proposal: <target name> <version>

Target:    code | prov artifact
Ships:     tag `<tag>` on `<sha>` + GitHub Release (latest)           # code
           `<kind>:<name>@release` -> `<kind>:<name>/<N>` (was /<M>)  # prov
Checks:    one line per pre-release check: pass, with its evidence (CI run URL, command output)
Notes:     the draft release notes (code) or the alias change and its trace summary (prov)
Depends:   prov alias versions the code needs, or `-`
Rollback:  triggers, steps, who acts (the agent at once on an agreed trigger; otherwise ask)
```

## Shipping

Only tags and the prov registry are pushed. `main` changes only by a squash-merged PR.
Nothing is rebased or force-pushed, and a pushed tag is never moved or deleted.

### Code

```bash
git tag -a <tag> <sha> -m "<tag>"
git push origin <tag>
gh release create <tag> --verify-tag --latest --title "<tag>" --notes-file <notes file>
```

Write the notes file in the session scratchpad, not in the repo.

### prov artifact

```bash
prov alias label <kind>:<name>@release <kind>:<name>/<N>
git -C <registry> push
```

`<registry>` is the `registry` path of the prov machine config. prov commits every label
move itself and never pushes; the push here is part of the confirmed release.

## Feature flags

A flag keeps an old path beside its replacement, so it is a deviation (code stance rule 6):
one `DEVIATIONS.md` row and a `DEVIATION(<id>)` comment at the flag, with the exit
condition "full rollout; the flag and the old path are removed".

**Feature flag lifecycle:**

```
1. MERGE with the flag OFF  → registered in DEVIATIONS.md
2. RELEASE                  → the code ships, inactive
3. ENABLE                   → for the user first, then everyone
4. VERIFY at each stage     → post-release checks, reported breakage
5. CLEAN UP                 → a PR removes the flag, the old path and the row
```

- Every flag has an owner and an exit condition
- Don't nest flags (it creates exponential combinations)
- Test both flag states (on and off) in CI

## Post-release verification

### Code

In a fresh environment in the session scratchpad, install from the tag and smoke-test it:

```bash
uv venv <scratch>/release-check
uv pip install --python <scratch>/release-check/bin/python "git+<repo url>@<tag>"
<scratch>/release-check/bin/python -c "import <module>"
<scratch>/release-check/bin/<cli> --help
```

In a multi-package repo, add `#subdirectory=packages/<package>` to the URL. A repo with no
Python package (the harness) checks instead that the Release exists and points at the tag
(`gh release view <tag>`).

### prov artifact

- `prov show <kind>:<name>@release` resolves to the shipped version
- The registry remote has the label commit (`git -C <registry> status -sb` shows nothing
  ahead)

Report the result either way.

## Rollback Strategy

Every release needs a rollback plan before it happens. Its triggers are agreed in the
proposal: when one fires, the agent rolls back at once and reports; on anything else, it
asks the user first.

```markdown
## Rollback Plan for [Release]

### Trigger Conditions
- The post-release check fails
- A downstream repo reports breakage pinned to [tag]
- [specific condition agreed in the proposal]

### Rollback Steps
Code:
1. Mark the Release withdrawn:
   `gh release edit <tag> --title "[withdrawn] <tag>" --latest=false`
   The tag stays: downstream may pin it.
2. Land the fix by a revert or fix PR (`dev-flow`, mode `fix/`)
3. Release the fixed version through a new proposal
prov artifact:
1. `prov alias label <kind>:<name>@release <kind>:<name>/<M>`, the previous version
2. `git -C <registry> push`

### Verify the rollback
- Code: `gh release view <tag>` shows the withdrawn title; the previous Release is latest
- prov: `prov show <kind>:<name>@release` resolves to `/<M>`
```

## See Also

- `dev-flow`, for the change itself, up to the squash-merged PR
- `CLAUDE.md`, Isolation and gates, for the release gate and the rules on `main`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "CI is green, so the release works" | CI tests the repo, not the installed tag. Run the post-release check. |
| "The user approved a release earlier" | Approval is per proposal. A new release, or a changed one, is a new proposal. |
| "The tag is wrong, I'll just move it" | Downstream may already pin it. Tags never move; release a new version. |
| "A quick rebase would tidy the history first" | Never rebase. `main` changes only by squash-merged PR. |
| "Rolling back is admitting failure" | Rolling back is responsible engineering. Leaving a broken release as latest is the failure. |
| "It's only a label move, it needs no proposal" | A label move is a release. It goes through the gate. |

## Red Flags

- Releasing without a confirmed proposal, or with the proposal and the release in the same turn
- Rebasing or force-pushing anything
- Moving or deleting a pushed tag, or repointing an alias version
- Pushing to `main` instead of opening a PR
- Releasing without a rollback plan
- A flag with no `DEVIATIONS.md` row
- No post-release check, or a failed one left unreported

## Verification

Before releasing:

- [ ] Pre-release checks pass, with their evidence
- [ ] Rollback plan written, triggers agreed
- [ ] Proposal shown and confirmed by the user in a later message

After releasing:

- [ ] Code: the tag and the Release exist, the Release is latest, the install smoke test passes
- [ ] prov: the label resolves to the shipped version, the registry remote has the commit
- [ ] The result is reported to the user
