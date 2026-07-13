# Environment Contract

This file defines the default runtime environment for this repository.

## Default Python Environment

- Environment manager: `conda`
- Activation script: `~/miniconda3/bin/activate`
- Default environment name: `dexpolicy`

## Activation

```bash
source ~/miniconda3/bin/activate dexpolicy
```

## Validation

```bash
python -V
which python
```

## Notes

- This file identifies the environment. Runtime behavior rules live in `.claude/policy/AGENT_RULES.md`.
- If the default environment changes, update this file and the policy references together.
