# Ship skill: agents release on the user's word

Branch: `feat/ship-skill` (mode `feat/` extend). Branch-only file; deleted at Finalize.

## Goal

Agents can ship and launch a release themselves, given the user's permission. Today the
harness stops at merge: `dev-flow` says "a confirmed stable release is published on purpose
by the user". This change adds the step after merge, as a skill copied from
`addyosmani/agent-skills` `skills/shipping-and-launch/SKILL.md` (upstream commit `8c99fa3`)
and amended where our ship methods differ.

## Decisions agreed with the user

1. **Release is a fifth gate.** The agent proposes a release; on the user's word it does all
   of it itself: tag, Release or label move, post-release check. A rollback needs the user's
   word too, unless a trigger agreed in the proposal fires; then the agent rolls back at once.
2. **Targets.** Code is published to GitHub only: a git tag plus a GitHub Release.
   Downstream repos pin to tags. No package index (PyPI) for now.
3. **prov artifacts.** prov is general provenance tracking, not a research tool; the skill
   never ties a release to research, experiments or `exp/`. Shipping a prov artifact moves
   the release label `kind:name@release` to a published alias version `kind:name/N` and
   pushes the registry. Labels are a convention in prov (prov ADR 0004, 0015); prov never
   pushes the registry itself (prov ADR 0010), so the push happens under the release gate.
4. **Tag at ship, only.** A tag means released. Merged but unreleased versions are pinned
   by commit SHA. `dev-flow`'s "on merge to `main`, CI creates the git tag" is replaced: no
   repo has that job.
5. **Main and history.** A rollback reaches `main` by a squash-merged revert or fix PR,
   never a direct push. Never rebase, never force-push, never move or delete a tag.
6. **Feature flags** are allowed only as registered deviations (code stance rule 6): one
   `DEVIATIONS.md` row each, exit condition "full rollout; the flag and the old path are
   removed".
7. **Intake:** copy upstream and amend in place (option 1 of 3), like the vendored
   superpowers skills. Rejected: keeping upstream pristine under a thin skill of ours (its
   contradicting lines would stay tracked, against ADR 0002), and writing our own skill
   from scratch (the user prefers copying).

## Contract

What the skill promises:

- No tag, GitHub Release or label move happens without a proposal the user confirmed.
- The proposal holds: the target, the version and tag name, the pre-release check results,
  the draft release notes, and the rollback plan with its triggers.
- Every release ends with a post-release check, and its result is reported.
- A rollback never deletes or moves a tag and never repoints an alias version.

### Checks

Before the proposal, for code:

1. The commit to tag is on `main` and its CI is green (`verify`/`test` and `gate`).
2. The version in the file the build reads it from (or the `Version:` line) equals the tag
   to be created, and no such tag exists yet.
3. Draft release notes: the PRs merged since the package's last tag, the ADRs they cite,
   `DEVIATIONS.md` rows added or removed, and any prov alias versions the code depends on.
4. The rollback plan and its triggers.

Before the proposal, for a prov artifact:

1. The alias version exists and `prov trace` resolves its lineage.
2. Its store bytes are present.
3. The registry is committed and in sync with its remote, apart from the label move.

After shipping:

- Code: in a fresh temporary environment, install from the tag (`git+...@<tag>`, with
  `#subdirectory=` in a multi-package repo) and run an import and `--help` smoke test.
- prov artifact: `prov show kind:name@release` resolves to the shipped version, and the
  registry remote has the label commit.

Rollback, triggered by a failed post-release check or reported breakage:

- Code: the GitHub Release is marked withdrawn (title prefix, no longer latest); the tag
  stays. The fix lands by a revert or fix PR, then a new release.
- prov artifact: the label moves back to the previous version.

## Variation axes

- **Release target**: code (git tag + GitHub Release) and prov artifact (label move). Both
  variants are real. A package index would be a new row of the skill's targets table, added
  only when one is used.
- **Tag naming** follows each repo's version scheme, which its gate already enforces:
  `v<version>` for a single-version repo (the harness, `Version:`), `<package>-v<version>`
  for a multi-package repo (prov: `prov`, `prov-journal`, `prov-skills`).

## Design

### The skill

`.claude/skills/shipping-and-launch/SKILL.md`, upstream name kept. Description: use when
releasing a version of a repo or of a prov artifact (tagging, a GitHub Release, moving a
release label) or rolling a release back; runs after merge. It must not trigger on writing
code, which is `dev-flow`'s.

| Upstream section | Here |
|---|---|
| Overview, When to Use | Kept, reworded: a release is reversible, observable and confirmed |
| Pre-Launch Checklist | Replaced by the checks above, for code and for prov artifacts |
| *(new)* The release gate | What the proposal holds (Contract) |
| Staged Rollout | Checks, proposal, the user's word, tag and Release or label move, post-release check |
| Feature Flag Strategy | Kept, shortened: a flag is a registered deviation |
| Monitoring, error reporting, error budget, rollout thresholds | Removed: service-only; the catch-all error handler conflicts with rule 1 |
| Post-Launch Verification | The post-release checks above |
| Rollback Strategy | Amended as above; the plan template kept |
| Common Rationalizations, Red Flags, Verification | Kept where they apply, plus ours: rebasing, force-pushing, moving or deleting a tag, pushing to `main`, releasing without the gate |
| See Also | `dev-flow` and `CLAUDE.md`; the `../../references/*` links go |

### Wiring

- `CLAUDE.md`, Isolation and gates: "Four things need the user's word" becomes five; the
  fifth is a release.
- `dev-flow`: the "Merging does not make a release" paragraph points to
  `shipping-and-launch`; the CI tag-on-merge line says the tag is created at release.
- `OPERATING_SPEC.md`: §1 lists the skill; §7 records it as copied from upstream at
  `8c99fa3` with its amendments listed; version 3.4.
- ADR 0010: agents release on the user's word; a tag is created at release only.

## Testing

- `verify_setup.sh`: the skill's file and frontmatter; pinned text that `CLAUDE.md` names
  the release gate among five; `dev-flow` no longer says CI creates the tag on merge; the
  skill carries no `git revert ... && git push`.
- `scripts/pr_gate.py` passes: ADR number unique, version raised, branch-only files gone.
- No live release runs on this branch. The first real release after merge (the harness at
  v3.4 is a natural candidate) is the skill's first end-to-end use.
