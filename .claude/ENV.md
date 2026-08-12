# Environment Contract

This file defines the default runtime environment for this repository.

## Default Python Environment

- Environment manager: `conda`
- Activation script: `~/sim-project_v3/.holosoma_deps/miniconda3/bin/activate`
- Recommended environments: `hssim`, `hsretarget` 

## Activation
Conda is not activatated by default in terminals. 

```bash
source ~/sim-project_v3/.holosoma_deps/miniconda3/bin/activate hssim
```

A separate home conda also exists, where the recommended env is `openmimic`:
```bash
source ~/miniconda3/bin/activate openmimic
```

## Validation

```bash
python -V
which python
```

## Notes

- A package resolves to its installed location in the env, not to your cwd; before trusting a worktree's tests, confirm it resolves to that worktree (`python -c "import <pkg>; print(<pkg>.__file__)"`).
- This file identifies the environment. Runtime behavior rules live in `.claude/policy/AGENT_RULES.md`.
- If the default environment changes, update this file and the policy references together.
