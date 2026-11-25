# Documentation defaults to the workspace's prov journal

Mode: `feat/` extend. Branch: `feat/journal-default`.

## Problem

A Claude workspace holds several sub-projects, and its documentation has drifted into loose
progress notes outside any repo, which prov cannot register. The user's framing: one prov journal
per Claude workspace, hosted in the workspace, and the documentation destination defaults to it.

## Contract

- CLAUDE.md (Research work): documentation defaults to the workspace's prov journal, `journal/`
  beside the workspace's `prov.toml`, a git repo of its own; notes written elsewhere are folded in.
- Session start, inside a prov project: names the journal as the default home for docs and its
  NOW.md; with a `prov.toml` and no `journal/`, says how to create it.

## Sketch (agreed 2026-11-25)

```
CLAUDE.md                        Research work: one bullet
.claude/hooks/session_start.sh   "- Journal: <dir>/journal, the default home for docs; read its NOW.md ..."
                                 or "- No journal yet: run prov-journal init in <dir>."
.claude/verify_setup.sh          both outputs, from a scratch prov project
docs/adr/0015-documentation-defaults-to-the-workspace-journal.md
```

Version 3.9 -> 3.10.
