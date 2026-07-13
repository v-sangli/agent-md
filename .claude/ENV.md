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

## Rules

- Use this environment by default for Python, pytest, uv, and dependency tasks unless the user explicitly asks for a different one.
- Run Python, pytest, uv, pip, install, build, and dependency workflows through `tmux-control`; direct opaque Bash is reserved for short read-only inspection.
- Validate the active Python with `python -V` and `which python` before building on the environment.
- If activation fails or dependencies are missing, stop and ask before switching environments, installing packages globally, or modifying system Python.
- Do not use `PYTHONPATH=.` as a durable fix. It is acceptable only as an explicitly named temporary diagnostic.
- Do not modify global/system Python environments without explicit user approval.
