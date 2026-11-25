# 0015. Documentation defaults to the workspace's prov journal

Status: Accepted (2026-11-25)
Covers: `CLAUDE.md` (Research work), `.claude/hooks/session_start.sh`, `.claude/verify_setup.sh`
PR: https://github.com/v-sangli/agent-md/pull/11; commits `557d449` (spec), `fa3b650` (plan, `docs/superpowers/plans/2026-11-25-journal-default.md`), `c491a82`, `11bd0d7`

## Context

A Claude workspace holds several sub-projects (repos) and one prov project: a `prov.toml` at the
workspace root that lists them. Before prov, documentation drifted into progress notes kept
outside every repo, which prov cannot register (a doc must be in a git repo, prov ADR 0019) and
which had to be folded in by hand. Nothing told an agent where documentation goes.

## Decision

- Each workspace has one prov journal: `journal/` beside the workspace's `prov.toml`, a git repo
  of its own, so the workspace root need not be one.
- Documentation defaults to that journal: findings, plans, investigations and progress notes are
  journal docs (`prov-journal` skill). A note written elsewhere is folded into it.
- Session start, inside a prov project, names the journal as the default home for docs and its
  `NOW.md`; when the project has no `journal/`, it says to run `prov-journal init` there.

## Consequences

- Easier: every session in a workspace knows where documentation goes, and every doc can be
  registered and cited.
- Code docs (READMEs, ADRs) stay in their repos; the default is for documentation of the work.

## Enforced by

`.claude/verify_setup.sh`: session start names the journal in a scratch prov project with a
journal, and says how to create one without it. Where an agent writes documentation is enforced
only by the user's review.
