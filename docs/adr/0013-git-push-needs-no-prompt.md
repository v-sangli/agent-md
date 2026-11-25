# 0013. `git push` needs no permission prompt

Status: Accepted (2026-11-25)
Covers: `.claude/settings.json` (`permissions.ask`), `.claude/policy/OPERATING_SPEC.md` (§2, §9 criterion 6)
PR: pending

## Context

`git push` sat on the permissions `ask` list beside `git reset --hard` and `sudo`, so every
push raised a prompt. The pushes it guarded no longer need one: `main` changes only by a
squash-merged PR, enforced by branch protection with required CI checks (ADR 0009); a
release, which pushes tags, needs the user's word (ADR 0010). What remained behind the
prompt was the push of a feature branch, which the user can veto in conversation.

## Decision

`Bash(git push:*)` is removed from `permissions.ask`. `git reset --hard` and `sudo` stay
there.

## Consequences

Agents push feature branches without a prompt. A push to `main` is still refused by branch
protection, and a tag push is still behind the release gate, which is a judgement the user
makes in conversation, not a permission rule.

## Enforced by

Nothing mechanical: the verifier checks that `sudo` stays on the `ask` list, and does not
check `git push` either way. The user's review is the enforcer.
