# prov integration Implementation Plan

> **For agentic workers:** executed inline (superpowers:executing-plans).

**Goal:** the harness installs prov (CLIs and the prov-skills plugin) once per machine at a ref.

**Architecture:** one Bash setup script under `.claude-workflow/`, documented in
`PORTABLE_SETUP.md`, checked by the verifier.

**Tech stack:** Bash, uv, the Claude Code plugin CLI, jq.

## Global Constraints

- Bash only (OPERATING_SPEC §10). No `$(...)` in commands run by agents; the script itself
  follows the repo's existing style.
- Harness version 3.6.

## Contract

- Decision: `install_prov.sh <ref>` installs prov, prov-journal and prov-skills@prov at that
  ref, idempotently; no submodule.
- Sketch: as in the spec (agreed 2026-11-24).
- Variation axes: none new.

---

### Task 1: the script and its verifier check

1. Add to `verify_setup.sh`: `need_file`/`need_exec` for `.claude-workflow/install_prov.sh` and
   `run_expect "install_prov.sh without a ref prints usage" 2 bash .claude-workflow/install_prov.sh`.
2. `bash .claude/verify_setup.sh` → FAIL on those three.
3. Write the script; `chmod +x`.
4. Verifier passes. Commit.

### Task 2: docs and rules

`PORTABLE_SETUP.md` (required tools: uv; new step), `.claude-workflow/README.md`, CLAUDE.md
Research work, OPERATING_SPEC file roles and Version 3.6. Verifier passes. Commit.

### Task 3: run it on this machine

After prov's release tag exists: `bash .claude-workflow/install_prov.sh <tag>`; `prov --help`,
`prov-journal --help`, `claude plugin list` shows `prov-skills@prov` at the tag's version.
