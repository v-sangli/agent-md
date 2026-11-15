---
name: dev-flow
description: Use before any code change in a repo - a new feature, an extension, a refactor or a bug fix - and before brainstorming, planning or debugging for one. Sets the order of work from request to merge, what each step is for and must produce, and the points where the user confirms before the next step.
---

# Dev Flow

The order of work for a code change in a repo, from request to merge.

## Why this flow exists

We kept having to refactor code because we did not agree with the design of its first
implementation. Three causes, each answered by a step below:

- We agreed on tasks, what to build, and never on interfaces: module boundaries and
  extension points. Answered by the interface checkpoint (step 5).
- There was no shared reference for what good looks like, so each design was judged from
  scratch. Answered by the code stance in `CLAUDE.md` and the repo's ADRs (step 3).
- The first design was scoped to the one use case in front of us, and the second use case
  broke it. Answered by the variation axes, named in the spec (step 4).

Rejecting a sketch costs a turn. Rejecting an implementation costs a refactor. The flow
puts the user's decisions where they are cheap.

## How to read it

- The rules that bind code are in `CLAUDE.md`: Code stance, When a test is red, Isolation
  and gates. This skill names a rule where it applies and does not restate it.
- Each step says what it is for and what it produces. The technique for a step lives in
  the skill the step names.
- **(gate)** marks a step that needs the user's word. Propose, then wait. Never start the
  next step on an assumed yes.
- Experiment work (`exp/`) is outside this flow.

| Step | Produces | `feat/` | `refactor/` | `fix/` |
|---|---|---|---|---|
| 1. Mode (gate) | the confirmed mode | yes | yes | yes |
| 2. Branch | the branch and its worktree | yes | yes | yes |
| 3. Read the ADRs | the constraints on the change | yes | yes | yes |
| 4. Design | the spec | yes | yes | no |
| 5. Interface checkpoint (gate) | the agreed sketch and an ADR | yes | yes | no |
| 6. Plan | the plan | yes | yes | no |
| 7. Spike (gate) | a finding | optional | optional | no |
| 8. Implement | the code and its tests | yes | yes | yes |
| 9. Finalize | one reviewable PR | yes | yes | yes |

## Step 1. Mode (gate)

The mode says where the change sits relative to an existing design. It decides which steps
apply and what the work owes. Propose one, with the reason, and wait for the user.

| Mode | When | What it owes |
|---|---|---|
| `feat/` greenfield | No design exists yet for this area. | Every step. The design is made here: the spec carries the contract and the variation axes, and the sketch is agreed before any plan. |
| `feat/` extend | A design exists and the feature is new to it. | Every step. Feature intake (code stance rule 3) picks the shape. A frozen core is touched only by full integration. |
| `refactor/` | Behavior stays the same; structure changes. | Every step. The oracle passes with no test edited. Consumers are mapped before anything is deleted. The plan carries a migration table. |
| `fix/` | The design is trusted and the code departs from it. | Steps 1 to 3, then 8 and 9. No spec, no plan, no spike. A failing test first, then a surgical fix. |

- To tell them apart, ask what the change does to the agreed contract. It adds to it:
  `feat/`. It leaves the contract and the behavior as they are: `refactor/`. It restores
  it: `fix/`.
- In the proposal, say which steps you expect to leave out and why. The user confirms that
  together with the mode.
- A switch of mode mid-work is explicit: stop, say what was found, and come back to this
  step. The usual causes: a fix exposes a design gap; a refactor needs a test edited, so it
  changes behavior; an extension turns out to need a new design.
- Someone else's bug is not a `fix/`. It is a deviation (code stance rule 6).
- If the repo lacks one of the CI checks listed at the end of this skill, say so here and
  add nothing on your own.

## Step 2. Branch

Nothing is written before the branch exists.

- Agree the code version with the user: an existing branch or a new one. `main` is never
  the working version. One feature per branch.
- Create the branch, named `<mode>/<short-name>`, in a worktree off `main`
  (`superpowers:using-git-worktrees`). The root checkout stays on `main`.
- A branch says what it is responsible for, so that anyone who opens it can tell:
  - `feat/` and `refactor/`: the spec is its first commit (step 4).
  - `fix/`: the branch is named for the bug, and its first commit is the failing test,
    whose message states the bug.

## Step 3. Read the ADRs

An ADR (architecture decision record) is the durable record of a design decision, and the
top reference: it cites the PR, the commits and the plan, and the PR cites it. The base
form is the common one: one numbered file per decision under `docs/adr/`, with Status,
Context, Decision and Consequences; an accepted decision is superseded by a new ADR, never
edited in place. We add four things:

1. **Enforced by.** A section naming the code or test that makes breaking the decision
   fail. A decision that can be tested becomes a CI test.
2. **Covered paths.** The ADR declares the paths it covers, so the ADRs for a change can
   be found from the files the change touches.
3. **Owner repo.** A decision that crosses repos lives in the repo that owns the contract.
   Other repos cite it with that repo's name.
4. **Frozen core.** What is frozen in a repo is what its ADRs declare (code stance rule
   7). The version stays `0.x` until an ADR declares the first frozen core.

Before designing:

- Find the ADRs that cover the paths the change will touch, and check whether any collide
  with the change or constrain it. A collision goes to the user: the ADR is respected, or
  the change ships with a new ADR that supersedes it.
- Where no ADR covers a claim about existing code, check the code.
- Read the repo's variation axes (its README or an ADR) and its `DEVIATIONS.md`.
- A repo with no ADRs yet has nothing to read here; step 5 writes its first one.

Template: `references/adr-template.md`.

## Step 4. Design

Produces the spec, committed as the branch's first commit under `docs/superpowers/specs/`.
`superpowers:brainstorming` carries the technique and hands back here. Not for `fix/`.

Beyond what brainstorming asks for, the spec states:

- **The contract.** What the change promises to its callers: the types that cross the
  boundary and the behavior behind them.
- **The variation axes.** A variation axis is a dimension along which the repo expects
  more than one variant; a loader that will read more than one file format has file format
  as an axis. The spec says which of the repo's axes the change is generic over and which
  it deliberately fixes. A new axis is named here and added to the repo's list. Generalize
  over known axes, stay concrete elsewhere.
- **The intake shape**, for an extension: subclass override, separate temporary
  standalone, or full integration (code stance rule 3), and why that one.
- **For a refactor:** the consumer map, which is every caller of what will move or be
  deleted, and the oracle that will show behavior unchanged. Where the code has no oracle,
  writing one is the plan's first task, before any code changes.

## Step 5. Interface checkpoint (gate)

Before any plan, agree a sketch of the interfaces with the user. The plan's tasks derive
from it, so nothing is planned until it is agreed. Not for `fix/`.

The sketch holds:

- **The objects.** Each class, what it owns, and its method signatures. No bodies.
- **The data that crosses between them.** Frozen dataclasses, or the language's typed and
  closed equivalent, with fields and types.
- **The directory layout**, when relevant: which subdirectory holds which objects.
- **A worked example** for each axis the change is generic over: "adding variant N+1
  touches these files and not those".
- A diagram is optional.

Show the sketch in the conversation and revise it until the user agrees. Then:

- Add the agreed sketch to the spec. It goes into the plan unchanged, as the plan's
  Contract section (step 6).
- Write its key decisions as an ADR with status Proposed, in the form of step 3. The ADR
  is completed at Finalize.

A worked sketch: `references/interface-sketch.md`.

## Step 6. Plan

Produces the plan under `docs/superpowers/plans/` (`superpowers:writing-plans`). Not for
`fix/`.

- The plan opens with a Contract section, copied from the agreed sketch: the Decision in a
  sentence or two, the signatures, and the variation axes. Tasks implement the contract
  and add nothing to it.
- A `refactor/` plan carries a migration table: one row for each thing that moves, is
  renamed or is deleted, with a Verify column giving the command or test that shows
  behavior unchanged.
- A greenfield plan sets up the repo's CI checks (end of this skill) among its tasks.
- Decide the version bump here or during implementation: patch for small things, minor for
  a feature, major for something major or breaking.

## Step 7. Spike, optional (gate)

A spike is reconnaissance: throwaway code that answers a question the design depends on,
and serves as reference for the implementation. It may come at any point once the branch
exists. Propose it with the question it answers, and open it only on the user's
greenlight. It is a gate because a spike is the least-effort edit, and least-effort edits
accumulate.

- It lives in `spikes/<name>/` on the branch, with a README: the question, the date of the
  greenlight, and the log of its monkey patches.
- The code rules for a spike are in `CLAUDE.md` (Isolation and gates): override only,
  shortcuts allowed, each monkey patch logged as a missing extension point.
- What the spike had to override is the list of seams the feature needs. Carry it into the
  sketch.
- Spike code never merges. `spikes/` is deleted at Finalize.

## Step 8. Implement

- `feat/` and `refactor/`: execute the plan with
  `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Each task
  follows `superpowers:test-driven-development`.
- `fix/`: write the failing test, find the cause (`superpowers:systematic-debugging`), and
  fix surgically. Investigating before fixing is the preference, with room for judgement.
- Write the code the contract calls for and nothing beyond it. A passing test is the
  check, not the target.
- A red test that the task did not just write gets a verdict before any fix (`CLAUDE.md`,
  When a test is red). A bug is fixed at its cause. A stale test is fixed and the reason
  stated. A feature gap goes through intake with the user. A design gap stops the work and
  returns to step 5.
- `refactor/`: no test is edited. Run the oracle before the first change and after each
  task.
- A gap in the contract found mid-task is reported. It is never bridged with a guard, a
  fallback, a `hasattr`, a variant `if` or a monkey patch.
- Commit on the branch, one commit per logical change.

## Step 9. Finalize

Turns the branch into one reviewable change. In this order:

1. **Update the branch from `main`.**
2. **Version.** Set the version, in the file the build reads it from, to `main`'s version
   plus the bump. Every merge to `main` raises the version, and downstream repos pin by
   version. A major bump cites an ADR.
3. **ADR.** Complete it with what changed during implementation. It cites the PR, the
   commits and the plan. Promote each remaining spec decision to an ADR or mark it local
   to the change.
4. **Deviations.** Each deviation the change leaves behind has its row in `DEVIATIONS.md`
   and its `DEVIATION(<id>)` comment at every code site. Remove the rows whose exit
   condition this change met.

   ```markdown
   | Id | Where | Why | Exit condition |
   |---|---|---|---|
   | D-001 | `readers/csv.py::CsvReader.read` | The upstream parser drops the last row of a file with no trailing newline (link to its issue). | An upstream release with the fix: remove the workaround and this row. |
   ```
5. **Delete the branch-only files:** the spec, the plan and `spikes/`. They stay readable
   in the PR's commits. Tracked code and docs cite none of them.
6. **Docs.** Where the change touches paths a doc covers and leaves that doc unchanged,
   say why in the PR.
7. **PR.** Open it for squash merge. Its description cites the ADR and carries one line
   for each plan item that was dropped.

A `fix/` runs items 1, 2, 4 and 7, and item 3 only if the fix changed a decision.

Merging does not make a release. A confirmed stable release is published on purpose by the
user, after due diligence outside CI: CI passing and production validation are different
claims.

## The CI checks the rules lean on

A rule holds because something enforces it: a CI check where the rule is mechanical, the
user's gate where it is a judgement. These are the mechanical ones. They live in each repo,
not in this harness.

| Check | Fails when |
|---|---|
| Tests, lint, invariant checks | Any of them fails. The testable ADR rules ("Enforced by") are among the tests, and one test runs the entry phase over every config. |
| Version raised | The version in the PR is not higher than `main`'s, or the branch is behind `main`. |
| Major bump has an ADR | A major bump comes with no change under `docs/adr/`. |
| Branch-only files gone | `spikes/`, `docs/superpowers/specs/` or `docs/superpowers/plans/` is still in the tree. |
| ADR numbers unique | Two ADRs carry the same number. |
| Deviations match | A `DEVIATION(<id>)` comment has no row in `DEVIATIONS.md`, or a row has no comment. |

Two more belong to the repo's setup: on merge to `main`, CI creates the git tag from the
version; and branch protection lets `main` change only by a squash-merged PR with green CI.

- Greenfield: setting these up is part of the first plan.
- An existing repo that lacks one: say so at step 1 and add nothing on your own. Until the
  check exists, the only enforcer of its rule is the user's review of the PR.

## When to stop and come back to the user

- At a gate: the mode, the interface checkpoint, a spike.
- On a change of mode.
- On a red-test verdict of feature gap or design gap.
- On a collision with an ADR.
- When making something work would take a guard, a fallback or a patch into the core. That
  is a gap in the contract; say so.
