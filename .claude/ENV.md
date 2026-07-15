# Environment Contract

This file defines the default runtime environment for this repository.

## Default Python Environment

- Environment manager: `conda`
- Activation script: `/data/miniconda3/bin/activate` (there is no `~/miniconda3` on this machine — verified 2026-07-14)
- Default environment name: `dexpolicy`

## Activation

```bash
source /data/miniconda3/bin/activate dexpolicy
```

## Validation

```bash
python -V
which python
```

## Worktrees

- A package resolves to its installed location in the env, not to your cwd; before trusting a worktree's tests, confirm it resolves to that worktree (`python -c "import <pkg>; print(<pkg>.__file__)"`).

## Notes

- This file identifies the environment. Runtime behavior rules live in `.claude/policy/AGENT_RULES.md`.
- If the default environment changes, update this file and the policy references together.
