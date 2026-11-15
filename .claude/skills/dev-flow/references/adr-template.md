# ADR template

File: `docs/adr/NNNN-short-slug.md`, numbered in order. The base form is the common one.
Of the four additions dev-flow step 3 describes, two are lines in the file, marked *ours*
below. The other two, the owner repo and the frozen core, show up in the rules and in
Consequences.

```markdown
# NNNN. <The decision, as a title>

Status: Proposed | Accepted | Superseded by NNNN
Covers: `path/one/`, `path/two.py`                      <!-- ours -->
PR: <link>, with its commits and the plan it carried    <!-- added once the PR is open -->

## Context

What forced a decision, and the constraints in play.

## Decision

The rule, stated so that a reviewer can check a diff against it.

## Consequences

What becomes easier, what becomes harder, and what is now frozen: the typed contract and
the tests that pin its behavior, if this ADR declares a frozen core.

## Enforced by                                           <!-- ours -->

The code or test that makes breaking this decision fail. If nothing can, say so: the
user's review is then its only enforcer.
```

## Rules

- **Status.** Proposed when written at the interface checkpoint, set to Accepted at
  Finalize, so it is Accepted on `main`. An accepted decision is never edited in place: a
  new ADR supersedes it, and the old one's status names the new number.
- **A change that collides with an accepted ADR** goes to the user: the ADR is respected,
  or the change ships with the ADR that supersedes it.
- **Across repos.** The ADR lives in the repo that owns the contract. Another repo cites it
  with the repo's name in front, for example `<repo> ADR 0007`.
- **Numbers.** Two parallel branches can pick the same number. The one that merges second
  renumbers at Finalize.
