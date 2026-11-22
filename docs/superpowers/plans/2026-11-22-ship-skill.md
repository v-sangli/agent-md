# Ship Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Agents ship releases (code and prov artifacts) themselves on the user's word, through a `shipping-and-launch` skill copied from upstream and amended.

**Architecture:** One standalone project skill, `.claude/skills/shipping-and-launch/SKILL.md`. `CLAUDE.md` gains the release as its fifth gate; `dev-flow` points to the skill after merge; `OPERATING_SPEC.md` records the copy and its amendments. `verify_setup.sh` pins the wiring.

**Tech Stack:** Markdown skills, bash verifier (`rg`), `scripts/pr_gate.py`.

## Global Constraints

- Upstream: `addyosmani/agent-skills`, `skills/shipping-and-launch/SKILL.md`, commit `8c99fa3`.
- Never rebase, never force-push, never move or delete a tag; `main` changes only by a squash-merged PR.
- The skill never ties a release to research, experiments or `exp/`.
- Tag names: `v<version>` single-version repo; `<package>-v<version>` multi-package repo.
- prov release label: `kind:name@release`.
- Harness version after this change: `3.4`.
- Shell commands in the skill use no `$(...)` or backticks (CLAUDE.md, Shell command shape).

## Contract

- Decision: a release is the fifth gate. The agent proposes, ends its turn, and on the
  user's word ships and verifies. The skill is upstream's, copied and amended in place.
- Sketch: as agreed, in `docs/superpowers/specs/2026-11-22-ship-skill-design.md`
  ("Agreed interface sketch"): the section outline, the release proposal form, the commands
  per target, and the package-index worked example.
- Variation axes: release target (code, prov artifact) is generic; a package index is not
  built.

---

### Task 1: The skill, with its verifier checks

**Files:**
- Create: `.claude/skills/shipping-and-launch/SKILL.md`
- Modify: `.claude/verify_setup.sh` (after the `need_file ".claude/skills/superpowers/..."` block, line ~117; and a new check block before `ss_out=`)

**Step 1: Write the failing checks.** After `need_file ".claude/skills/superpowers/skills/brainstorming/SKILL.md"` add:

```bash
need_file ".claude/skills/shipping-and-launch/SKILL.md"
```

Before the `ss_out=` line add:

```bash
ship_ok=1
ship_md="$REPO_DIR/.claude/skills/shipping-and-launch/SKILL.md"
if [ -f "$ship_md" ]; then
  for required in "## The release gate" "## Release targets" "@release" "8c99fa3"; do
    rg -Fq "$required" "$ship_md" || ship_ok=0
  done
  rg -q 'git revert .*&& *git push' "$ship_md" && ship_ok=0
  rg -q 'git push[^`]*(--force|-f |main)' "$ship_md" && ship_ok=0
else
  ship_ok=0
fi
if [ "$ship_ok" -eq 1 ]; then
  pass "shipping-and-launch: release gate, targets, no push to main or force-push"
else
  fail "shipping-and-launch: release gate, targets, no push to main or force-push"
fi
```

**Step 2: Run, expect FAIL.** `bash .claude/verify_setup.sh | rg 'shipping-and-launch'` shows `missing file` and the `FAIL | shipping-and-launch: ...` line.

**Step 3: Write the skill.** Create `.claude/skills/shipping-and-launch/SKILL.md` with the content in the appendix of this plan, verbatim.

**Step 4: Run, expect PASS.** Same command: both lines PASS; the frontmatter loop reports no problem for `shipping-and-launch/SKILL.md`. Overall summary: only the known `tmux-control root request` failure remains.

**Step 5: Commit.** `git add .claude/skills/shipping-and-launch .claude/verify_setup.sh && git commit -m "Add shipping-and-launch, copied from agent-skills 8c99fa3 and amended"`

### Task 2: Wire the gate into CLAUDE.md and dev-flow

**Files:**
- Modify: `CLAUDE.md` (Isolation and gates, "Four things need the user's word", line 119, and the end of that list)
- Modify: `.claude/skills/dev-flow/SKILL.md` (lines 239-241 and the "Two more belong to the repo's setup" paragraph; "When to stop" list)
- Modify: `.claude/verify_setup.sh` (the `policy_ok` CLAUDE.md loop)

**Step 1: Write the failing checks.** In the `policy_ok` loop over `CLAUDE.md`, add `"Five things need the user's word"` and `"**A release.**"`. After the loops add:

```bash
rg -Fq "CI creates the git tag" "$REPO_DIR/.claude/skills/dev-flow/SKILL.md" && policy_ok=0
rg -Fq "shipping-and-launch" "$REPO_DIR/.claude/skills/dev-flow/SKILL.md" || policy_ok=0
```

**Step 2: Run, expect FAIL** on `policy docs are restored for the lean harness`.

**Step 3: Edit.**

`CLAUDE.md`: `Four things need the user's word.` becomes `Five things need the user's word.` After the `exp/` bullet append:

```markdown
- **A release.** A tag, a GitHub Release, or a prov release label moved. The agent
  proposes it with its checks and its rollback plan, ends its turn, and ships it only on
  the user's word (`shipping-and-launch`). A release pushes tags and the prov registry,
  never `main`.
```

`dev-flow` Step 9, replace the closing paragraph with:

```markdown
Merging does not make a release. A release is the fifth gate (`CLAUDE.md`, Isolation and
gates), run by `shipping-and-launch`: CI passing and a verified release are different
claims.
```

`dev-flow` CI checks section, replace `on merge to \`main\`, CI creates the git tag from the
version;` with `a tag is created only at release (\`shipping-and-launch\`);`.

`dev-flow` "When to stop", first bullet becomes `- At a gate: the mode, the interface sketch, a spike, a release.`

**Step 4: Run, expect PASS** for the policy check; `wc -l CLAUDE.md` stays under 300.

**Step 5: Commit.** `git commit -am "Release is the fifth gate; dev-flow hands off to shipping-and-launch"`

### Task 3: Record the copy in the operating spec

**Files:**
- Modify: `.claude/policy/OPERATING_SPEC.md` (`Version:` line; §1 file roles; §7)
- Modify: `.claude/PORTABLE_SETUP.md` (installed-skills list, line ~71)

**Step 1: Run the gate, expect FAIL.** `python3 scripts/pr_gate.py --base origin/main` reports the version not raised.

**Step 2: Edit.**
- `Version: 3.3` → `Version: 3.4`.
- §1, after the `tmux-control` row: `.claude/skills/shipping-and-launch/ releases: the fifth gate, after merge; copied and amended (section 7)`.
- §7, after the first paragraph, add:

```markdown
`shipping-and-launch` is copied from `addyosmani/agent-skills`
(`skills/shipping-and-launch/SKILL.md`, commit `8c99fa3`) as a standalone skill; the rest of
that repo is not taken. Local changes, all in skill text (ADR 0010):

- its description and When to Use fire on releasing, after merge, not on writing code;
- the web-service checklists become checks for code (tag, CI, version, notes) and for prov
  artifacts (alias version, lineage, bytes, registry);
- staged rollout becomes the release gate: proposal, end of turn, the user's word;
- shipping is an annotated tag plus a GitHub Release, or a prov `@release` label move;
- feature flags are registered deviations; the error-reporting code, monitoring, error
  budget and rollout thresholds are removed;
- rollback never deletes or moves a tag and reaches `main` by a revert or fix PR;
- the `../../references/` links go; the red flags add rebasing, force-pushing, moving a tag
  and releasing without the gate.

An upstream update means re-applying these.
```

- `PORTABLE_SETUP.md`, after the `dev-flow` bullet: `` - `shipping-and-launch` is installed in `.claude/skills/shipping-and-launch/` ``.

**Step 3: Run, expect PASS.** `python3 scripts/pr_gate.py --base origin/main` fails only on the branch-only files (removed at Finalize); `bash .claude/verify_setup.sh` shows only the known failure.

**Step 4: Commit.** `git commit -am "Record shipping-and-launch in the operating spec; harness 3.4"`

---

## Appendix: `.claude/skills/shipping-and-launch/SKILL.md`

Task 1 Step 3 copies the block below into the file, between the `~~~~` fences.

~~~~markdown
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
~~~~
