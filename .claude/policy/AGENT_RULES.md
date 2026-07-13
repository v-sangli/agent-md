# Agent Rules

This is the canonical short runtime contract for this Claude workspace. Other
docs may explain or route these rules, but should not silently strengthen them.
Design rationale and acceptance criteria live in
`.claude/policy/OPERATING_SPEC.md`.

## Non-Negotiables

1. Workspace boundary.
- Write/delete work stays inside the repo unless the user grants external scope.
- External writes/deletes require `.claude/harness/run.sh` to ask, or a scoped grant in `.claude/access.conf`.
- `.claude/**` is protected during ordinary task work; edit it only for explicit Claude setup maintenance.

2. Shell execution.
- Direct Bash is for short read-only inspection.
- Shell writes/deletes go through `.claude/harness/run.sh -- '<command>'`.
- Tests, installs, builds, benchmarks, nested agents, and long-running work go through `tmux-control`.

3. Privilege.
- Do not run or suggest opaque sudo: no direct `sudo`, in-session `! sudo`, `sudo -S`, password piping, or askpass workaround.
- Privileged continuation uses `tmux-control` root-request and an explicitly approved visible root tmux session.
- Lesser-privilege results are acceptable only when they are true equivalents, not compromises.

4. Environment.
- Read `.claude/ENV.md` before Python, pytest, uv, dependency, install, or build work.
- Use the `dexpolicy` conda environment by default unless the user overrides it.
- Do not use `PYTHONPATH=.` as a durable fix.

5. External monkey patches.
- Do not patch `site-packages`, system paths, external dependency checkouts, or other outside-repo code without explicit approval.
- Prefer in-repo fixes, dependency pins/upgrades, wrappers, or vendored patches.

6. Change discipline.
- Try at most one minimal hypothesis-driven patch for a new bug before switching to investigation.
- Extend existing modules/helpers before adding parallel systems.
- Propose subsystem-level refactors first; use a worktree for non-trivial refactors when practical.

7. Verification.
- Define success criteria before substantial edits.
- Run the smallest meaningful validation after edits.
- For harness changes, `bash .claude/verify_setup.sh` is the baseline verifier.
