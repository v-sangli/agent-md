# Claude Operating Specification

Version: 2.0
Scope: Current lean Claude Code workspace/harness in this repository.

This specification replaces the original policy bundle that depended on
persistent agent memory files, separate debug helper scaffolding, and contract
hash blocking. Those systems are intentionally not active in this workspace.

## 1. Purpose

This document defines:

1. What Claude may change.
2. How shell mutation, sudo, and long-running work must be routed.
3. How environment assumptions are handled.
4. How debugging, refactoring, and validation should proceed.
5. What counts as a correct portable harness setup.

Normative keywords:

- MUST: mandatory.
- MUST NOT: forbidden.
- SHOULD: default unless explicitly overridden by the user.
- MAY: acceptable when appropriate.

## 2. Current Workspace Model

The active workspace shape is:

```text
repo/
  CLAUDE.md
  HARNESS_CHECKLIST.md
  .claude/
    ENV.md
    PORTABLE_SETUP.md
    access.conf
    settings.json
    settings.local.json
    harness/
      run.sh
    hooks/
      access_guard.sh
      pre_tool_use_bash_guard.sh
      pre_tool_use_guard.sh
      post_tool_use_privilege_guard.sh
      session_start.sh
    policy/
      AGENT_RULES.md
      OPERATING_SPEC.md
    skills/
      tmux-control/
      dx/
      superpowers/
    verify_setup.sh
  .claude-workflow/
```

Runtime logs, old benchmark state, and generated control captures are not part
of the portable contract.

## 3. Root Of Trust

- REQ-001: `CLAUDE.md` MUST remain the concise always-loaded project memory.
- REQ-002: `.claude/policy/AGENT_RULES.md` MUST remain the concise runtime rule summary.
- REQ-003: `.claude/policy/OPERATING_SPEC.md` MUST remain the fuller operating specification.
- REQ-004: `.claude/ENV.md` MUST remain the canonical environment contract.
- REQ-005: `.claude/settings.json`, `.claude/hooks/**`, `.claude/harness/**`, `.claude/access.conf`, and `.claude/skills/**` define active enforcement and workflow behavior.
- REQ-006: Policy hash drift blocking is not active unless explicitly reintroduced and documented in `HARNESS_CHECKLIST.md`.

## 4. Ownership Boundaries

- REQ-007: Claude MAY edit normal repository files under the workspace root.
- REQ-008: Claude MUST NOT edit files outside the workspace root unless the user explicitly requests or approves that scope.
- REQ-009: `.claude/**` MUST be treated as protected configuration during ordinary task work.
- REQ-010: Claude MAY edit `.claude/**` during explicit harness/Claude-setup maintenance requested by the user.
- REQ-011: Protected `.claude/**` mutation through shell commands SHOULD use `.claude/access.conf` `maintainer_mode=true` or equivalent explicit user approval.
- REQ-012: `.git/**`, filesystem roots, home directory roots, and system paths such as `/etc`, `/usr`, `/var`, `/boot`, `/dev`, `/proc`, and `/sys` MUST be treated as critical write/delete targets.

## 5. Shell Execution Policy

- REQ-013: Direct Bash SHOULD be limited to short read-only inspection.
- REQ-014: Shell writes/deletes MUST run through `.claude/harness/run.sh -- '<command>'`.
- REQ-015: The harness MAY execute workspace-scoped writes/deletes and safe `/tmp` content cleanup.
- REQ-016: The harness MUST stop and ask for non-critical external writes/deletes unless `.claude/access.conf` grants the exact access class and optional root scope.
- REQ-017: The harness MUST stop without running critical writes/deletes.
- REQ-018: Direct tests, installs, builds, benchmarks, interpreters, nested agents, servers, watchers, and long-running commands MUST be routed through `tmux-control`.
- REQ-019: Shell commands with dynamic or unresolved write/delete targets SHOULD stop and ask instead of guessing.

## 6. Sudo And Privilege Policy

- REQ-020: Claude MUST NOT run `sudo` in opaque Bash.
- REQ-021: Claude MUST NOT suggest in-session `! sudo`, `sudo -S`, password piping, askpass hacks, or similar password workarounds.
- REQ-022: Privileged continuation MUST use the `tmux-control` root-request flow and an explicitly approved visible root tmux session.
- REQ-023: When the best direct execution needs privilege, Claude MUST say so even if a lesser-privilege result is also available.
- REQ-024: A lesser-privilege path MAY be used only when it is a true equivalent for the user request and does not create a brittle foundation for later work.
- REQ-025: If the no-root path is partial, temporary, non-portable, changes the intended environment, or weakens the task, Claude MUST stop and request the approved root tmux path.

## 7. Environment Policy

- REQ-026: Environment assumptions MUST be sourced from `.claude/ENV.md`.
- REQ-027: Python, pytest, uv, dependency, install, and build work SHOULD use the `dexpolicy` conda environment unless the user explicitly overrides it.
- REQ-028: Claude SHOULD validate the active Python with `python -V` and `which python` before building on the environment.
- REQ-029: If activation fails or dependencies are missing, Claude MUST stop and ask before switching environments, installing globally, or modifying system Python.
- REQ-030: `PYTHONPATH=.` MUST NOT be used as a durable fix. It MAY be used only as an explicitly named temporary diagnostic.

## 8. External Monkey Patch Policy

- REQ-031: Direct edits to `site-packages`, system paths, external dependency checkouts, or other paths outside the repo are prohibited by default.
- REQ-032: If external patching appears necessary, Claude MUST stop and ask for explicit user approval.
- REQ-033: Claude SHOULD prefer in-repo fixes, dependency pins/upgrades, wrappers, or vendored patches over external monkey patches.

## 9. Debugging And Change Discipline

- REQ-034: For a new bug, Claude MAY try one minimal hypothesis-driven patch.
- REQ-035: If a similar failure repeats, Claude MUST stop patching and switch to investigation before further fixes.
- REQ-036: Investigation SHOULD gather targeted evidence, name the active hypothesis, and verify the hypothesis before changing more code.
- REQ-037: Claude SHOULD prefer line-tagged diagnostics and focused repros over broad exploratory churn.
- REQ-038: Claude MUST keep changes surgical and traceable to the user request.
- REQ-039: Claude SHOULD extend existing modules/helpers before creating parallel replacements.
- REQ-040: Subsystem-level refactors MUST be proposed first and require user approval.
- REQ-041: Non-trivial refactor work SHOULD use a git worktree.

## 10. Validation Policy

- REQ-042: Claude MUST define success criteria before substantial edits.
- REQ-043: Claude MUST run meaningful validation after meaningful edits when feasible.
- REQ-044: For harness changes, `bash .claude/verify_setup.sh` is the baseline offline verifier.
- REQ-045: Test, build, install, benchmark, and long-running validation SHOULD run through `tmux-control`.
- REQ-046: If validation cannot be run, Claude MUST say why and describe residual risk.

## 11. Skills And Plugins

- REQ-047: `.claude/skills/tmux-control/` is the project skill for visible persistent shell work.
- REQ-048: `.claude/skills/dx/` and `.claude/skills/superpowers/` are vendored project-scope plugin directories.
- REQ-049: Third-party skills/plugins SHOULD be copied as complete project-scope plugin directories when their repo-level glue files matter.
- REQ-050: Modified third-party skills/plugins SHOULD either be tracked in this repo intentionally or moved to a forked upstream; do not silently flatten or partially copy plugin repos.

## 12. Offline And Portability Contract

- REQ-051: Core harness verification MUST work offline.
- REQ-052: Web access and external marketplace plugins are optional accelerators, not hard dependencies.
- REQ-053: `.claude/PORTABLE_SETUP.md` MUST describe how to bundle, install, chmod, and verify the workspace setup.
- REQ-054: `.claude-workflow/bundle_claude_dirs.sh` SHOULD package `CLAUDE.md`, `.claude/`, and `.claude-workflow/`.
- REQ-055: Generated runtime state such as `.tmux-control/` MUST remain out of versioned portable setup unless explicitly requested.

## 13. Acceptance Criteria

Setup is considered correct when all are true:

1. `bash .claude/verify_setup.sh` passes.
2. Root `CLAUDE.md` points to the current policy and environment docs.
3. `.claude/policy/AGENT_RULES.md` and `.claude/policy/OPERATING_SPEC.md` describe the current lean harness, not the removed runtime systems.
4. Direct Bash writes/deletes are blocked and routed to `.claude/harness/run.sh`.
5. Workspace writes/deletes and safe `/tmp` content cleanup execute only through the harness.
6. External writes/deletes ask unless explicitly granted in `.claude/access.conf`.
7. Critical destructive requests stop without running.
8. Direct sudo and in-session sudo suggestions are redirected to the root tmux request flow.
9. Direct tests/installs/builds/benchmarks are routed to `tmux-control`.
10. Environment behavior points to `.claude/ENV.md` and rejects durable `PYTHONPATH=.` workarounds.

## 14. Maintenance Procedure

When updating this harness intentionally:

1. Update `HARNESS_CHECKLIST.md` with the decision being made.
2. Edit the smallest set of `.claude/**` and root docs needed for the change.
3. Keep active scripts Bash-only.
4. Run `bash .claude/verify_setup.sh`.
5. Review `git diff` before committing.
