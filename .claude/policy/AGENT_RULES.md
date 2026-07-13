# Agent Rules

This is the short runtime contract for this Claude workspace. The full rationale
and acceptance criteria live in `.claude/policy/OPERATING_SPEC.md`.

## Non-Negotiables

1. Stay inside the workspace unless the user explicitly grants external access.
- Normal file writes/deletes are allowed inside the repo.
- External writes/deletes require the access harness to ask or a scoped grant in `.claude/access.conf`.

2. Treat `.claude/**` as protected configuration.
- Normal task work must not modify `.claude/**`.
- Claude setup maintenance may modify `.claude/**` only when the user is intentionally working on the harness.
- `.claude/access.conf` `maintainer_mode=true` is the explicit local switch for protected `.claude/**` mutations through the harness.

3. Use the script harness for shell writes/deletes.
- Direct Bash is for short read-only inspection.
- Shell writes/deletes must run through `.claude/harness/run.sh -- '<command>'`.
- Direct tests, installs, builds, benchmarks, nested agents, and other long-running work belong in `tmux-control`.

4. Do not run or suggest opaque sudo.
- Direct `sudo`, in-session `! sudo`, `sudo -S`, and password workarounds are not supported.
- Privileged continuation must use the `tmux-control` root-request flow and an explicitly approved visible root tmux session.

5. Follow the environment contract.
- Read `.claude/ENV.md` before Python, pytest, uv, dependency, install, or build work.
- Use the `dexpolicy` conda environment by default unless the user explicitly overrides it.
- Do not use `PYTHONPATH=.` as a durable fix.

6. Avoid external monkey patches.
- Do not patch `site-packages`, system paths, or dependency installs outside the repo without explicit user approval.
- Prefer in-repo fixes, dependency pins/upgrades, wrappers, or vendored patches.

7. Make one minimal patch, then investigate.
- For a new bug, one small hypothesis-driven patch is acceptable.
- If a similar failure repeats, stop patching and switch to investigation: gather targeted evidence, name the hypothesis, and verify before changing more code.

8. Prefer existing structure.
- Extend existing modules and helpers before adding parallel systems.
- Subsystem-level refactors require user approval and should generally use a worktree.

9. Verify meaningful changes.
- Define success criteria before substantial edits.
- Run the smallest meaningful validation after edits.
- For this harness, `bash .claude/verify_setup.sh` is the baseline verifier.
