# 0011. prov is installed once per machine, pinned to a release; no submodule

Status: Accepted (2026-11-24)
Covers: `.claude-workflow/install_prov.sh`, `.claude/PORTABLE_SETUP.md`, `CLAUDE.md` (Research work)
PR: (pending); commits `7ca0e4a` (spec), `bfc11e8` (plan, `docs/superpowers/plans/2026-11-24-prov-integration.md`), `09b26c9`, `df89fad`

## Context

CLAUDE.md sends experiment work to `prov` and its skills, and the harness did not install
either. One machine runs several workspaces against one prov registry, store and config. A
git submodule would put a copy of prov in each workspace, each at its own commit, so two
workspaces could drift onto versions that disagree about the records they share. prov ADR
0021 ships the skills as a user-scope Claude Code plugin, `prov-skills@prov`.

## Decision

- prov is a machine-level tool, not part of any workspace. `.claude-workflow/install_prov.sh
  <ref>` installs it at one prov ref, a release tag:
  - the `prov` and `prov-journal` CLIs with `uv tool install` from that ref;
  - the `prov` marketplace pinned to that ref (removed and added again when it is at another
    ref) and the `prov-skills` plugin at user scope.
- Every workspace on the machine sees the same CLIs and skills. A project whose code imports
  `prov` or `prov_skills.plot` adds them to its own environment from the same tag.
- No submodule, and no copy of prov in the harness or in a workspace.
- CLAUDE.md's Research work names the plugin, and an ID or alias is resolved with prov before
  anything is assumed about it.
- The prov repo is `PROV_REPO`, defaulting to the upstream one, so the template carries no
  other machine detail.

## Consequences

- Easier: one prov per machine; the version every workspace uses is the ref the script was
  last run with.
- Harder: a prov upgrade is a rerun of the script with the new tag; it is not tracked in any
  workspace's git history.
- The skills' contract lives in prov (prov ADR 0021); this harness only installs them.

## Enforced by

`.claude/verify_setup.sh`: the script exists, is executable, and exits 2 with its usage when
given no ref. That it installs is checked by running it, which needs the network; the user's
review covers it.
