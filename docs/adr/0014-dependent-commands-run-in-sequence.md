# 0014. A command that depends on another's success runs after it

Status: Accepted (2026-11-25)
Covers: `CLAUDE.md` (Shell command shape)
PR: https://github.com/v-sangli/agent-md/pull/10

## Context

An agent sent a PR merge and the deletion of that PR's branch as parallel tool calls. A
permission check denied the merge; the deletion ran anyway, and deleting the head branch
closed the open PR. The branch was pushed back from the local copy and the PR reopened at
the same commit, so nothing was lost, but the deletion was only ever meant to follow a
successful merge.

## Decision

`CLAUDE.md` (Shell command shape) states: a command that should run only if another
succeeds goes after it, chained with `&&` or in a later turn once its result is seen, and
never in the same batch of parallel calls.

## Consequences

Parallel calls stay the default for independent work. A dependent step costs one more turn
or one chained command.

## Enforced by

Nothing mechanical: the order of an agent's tool calls is not visible to CI. The user's
review is the enforcer.
