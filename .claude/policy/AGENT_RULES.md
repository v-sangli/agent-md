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
- Direct Bash covers read-only inspection, interpreter one-liners (`python -c`, `pip show`-class queries), and workspace//tmp writes; the Bash guard classifies each command, and unclassifiable ones fall through to native asks.
- External writes/deletes surface as asks; pre-grant roots in `.claude/access.conf` or route explicitly through `.claude/harness/run.sh -- '<command>'`.
- Tests, installs, builds, benchmarks, nested agents, and long-running work go through `tmux-control`.
- `.claude/` tooling lives at the workspace root; from a nested cwd (e.g. a worktree) invoke helpers by absolute path.

3. Privilege.
- Do not run or suggest opaque sudo: no direct `sudo`, in-session `! sudo`, `sudo -S`, password piping, or askpass workaround.
- Privileged continuation uses `tmux-control` root-request and an explicitly approved visible root tmux session.
- Lesser-privilege results are acceptable only when they are true equivalents, not compromises.

4. Environment.
- Read `.claude/ENV.md` before Python, pytest, uv, dependency, install, or build work.
- Use the `dexpolicy` conda environment by default unless the user overrides it.
- Treat the shared conda env as stable infrastructure. A one-shot `PYTHONPATH=<src>` (or `PYTHONPATH=.`) injection scoped to a test invocation is fine by best judgment for exercising unmerged/worktree/candidate code (it shadows pure-Python code only — a compiled extension still resolves to the installed build); do not use it as a durable substitute for a real install.
- Durable env mutations (installs, upgrades, editable repoints) stay ask-gated: surface the intended change, prefer a `pip install --dry-run` resolver check first, and get user approval before mutating the shared env.

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
