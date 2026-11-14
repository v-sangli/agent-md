---
name: dev-flow
description: Use before any code change in a repo - a new feature, a refactor or a bug fix. Sets the order of work from request to merge and the points where the user must confirm before the next step.
---

# Dev Flow

The order of work for a code change in a repo, from request to merge.

The rules are in `CLAUDE.md` (Code stance; Isolation and gates) and are not repeated here.
Each step names the skill that carries its technique. **(gate)** marks a step that needs
the user's word before the next one starts.

## Steps

1. **Mode (gate).** Propose `feat/`, `refactor/` or `fix/` and wait for the user to
   confirm.
2. **Branch and worktree.** Create the branch, named by its mode, in a worktree off `main`
   (`superpowers:using-git-worktrees`). Nothing is written before the branch exists. The
   branch's charter is its spec for `feat/` and `refactor/`, its PR description for `fix/`.
3. **Read the ADRs** that cover the paths the change will touch. Check whether any collide
   with the change or constrain it. Where no ADR covers a claim about existing code, check
   the code.
4. **Design** (`superpowers:brainstorming`). An extension of existing code starts with the
   feature-gap question (code stance rule 3). The spec states which of the repo's variation
   axes it is generic over and which it deliberately fixes.
5. **Interface checkpoint (gate).** Before any plan, agree a sketch with the user:
   signatures and frozen dataclasses, no bodies, and a worked example of "adding variant
   N+1 touches these files and not those". Then write the ADR for the key decisions; it
   declares the paths it covers.
6. **Plan** (`superpowers:writing-plans`). Decide the version bump here or during
   implementation: patch for small things, minor for a feature, major for something major
   or breaking.
7. **Spike, optional (gate).** Propose it; open it only on the user's greenlight.
8. **Implement** (`superpowers:subagent-driven-development` or
   `superpowers:executing-plans`, with `superpowers:test-driven-development`). A `fix/`
   finds the root cause first (`superpowers:systematic-debugging`).
9. **Finalize.**
   - Update the branch from `main`.
   - Set the version in the repo's version file to `main`'s version plus the bump. A major
     bump cites an ADR. The version stays `0.x` until an ADR declares the first frozen
     core.
   - Update the ADR with what changed during implementation. The ADR cites the PR, its
     commits and the plan; the PR cites the ADR.
   - Promote each spec decision to an ADR or mark it local to the change. Then delete the
     spec, the plan, the SDD files and the spikes.
   - In the PR description: one line for each plan item that was dropped; and, where the
     change touches paths a doc covers without changing that doc, the reason.
   - Open the PR for squash merge.

Merging does not make a release. A confirmed stable release is published on purpose by the
user, after due diligence outside CI.

## By mode

- `feat/`: every step.
- `refactor/`: every step. The plan carries a migration table with a Verify column. Map
  the consumers of a thing before deleting it.
- `fix/`: steps 4 to 7 do not apply; there is no spec, plan or spike.
- `exp/`: not covered by this flow.

## Stops

During step 8, any verdict other than a bug stops the work and goes back to the user
(`CLAUDE.md`, "When a test is red"). A change of mode restarts at step 1.
