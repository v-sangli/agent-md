# 0011. prov is installed once per machine, from one clone at a release; no submodule

Status: Accepted (2026-11-25)
Covers: `.claude-workflow/install_prov.sh`, `.claude/hooks/session_start.sh`, `.claude/PORTABLE_SETUP.md`, `CLAUDE.md` (Research work)
PR: https://github.com/v-sangli/agent-md/pull/6

## Context

CLAUDE.md sends experiment work to `prov` and its skills, and the harness did not install
either. One machine runs several workspaces against one prov registry, store and config. A
git submodule would put a copy of prov in each workspace, each at its own commit, so two
workspaces could drift onto versions that disagree about the records they share. A Claude Code
plugin (prov ADR 0021, superseded by prov ADR 0022) was a second copy of the skills managed by
Claude Code, and could not carry the CLIs or a Python environment.

## Decision

- prov is a machine-level tool, not part of any workspace. `.claude-workflow/install_prov.sh
  <ref>` installs it at one ref, a release tag:
  - one clone at `PROV_HOME` (`~/.local/share/prov`), detached at the ref;
  - its own venv in the clone, holding `prov` and `prov-journal` (not editable, so the venv
    is the ref's code); prov's dependencies stay few (pydantic, pyyaml, duckdb);
  - `prov` and `prov-journal` linked into `~/.local/bin`; each skill directory under
    `packages/prov-skills/skills/` (prov ADR 0022) linked into `~/.claude/skills/`. A path
    that exists and is not a link is never replaced;
  - a pointer file, `~/.config/prov/install.toml`: home, ref, commit, python, bin, skills,
    usage doc.
- Session start reads the pointer file. Present: prov's ref, commit, home, CLIs, skills and
  usage doc. Absent: prov is not installed, and the command to propose to the user. When a
  `prov.toml` is at or above the project root, it also says the workspace is a prov project
  and to read `journal/NOW.md`.
- A run whose code imports prov installs it into the run's own environment from the same
  clone (`uv pip install <home>/packages/prov`), so it matches the machine's version.
- The installer writes outside the workspace, so the agent proposes running it and the user
  approves.
- No submodule and no copy of prov in the harness. Paths and the repo URL are environment
  variables with defaults, so the template carries no other machine detail.

## Consequences

- Easier: one prov per machine; the version every workspace uses is the ref the script last
  ran with, and the pointer file says which.
- Easier: one clone serves the CLIs, the skills, the docs and project installs.
- Harder: an upgrade is a rerun with a new tag; it is not tracked in any workspace's history.
- prov's development checkout is separate from the machine's clone, so a prov branch in
  progress never changes what agents run.

## Enforced by

`.claude/verify_setup.sh`: the script exists, is executable and exits 2 with its usage when
given no ref; session start reports an installed prov from a pointer file and gives the
install command without one. That the script installs is checked by running it, which needs
the network; the user's review covers it.
