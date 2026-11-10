# Portable Claude Setup

Use this to reproduce the same Claude Code behavior in another repo directory or computer.

## 0) Required local tools

The harness scripts are Bash-only and expect:

```bash
bash
jq
rg
realpath
tmux
zip
unzip
```

## 1) Create and transfer archive

From the source repo root:

```bash
bash .claude-workflow/bundle_claude_dirs.sh
```

Copy `claude-workflow-bundle.zip` to the target machine/repo.

## 2) Install into target repo

From target repo root:

```bash
unzip claude-workflow-bundle.zip
```

Optional local override file if missing:

```bash
[ -f .claude/settings.local.json ] || cat > .claude/settings.local.json <<'JSON'
{
  "permissions": {
    "allow": []
  }
}
JSON
```

## 3) Ensure hook executables

```bash
chmod +x .claude/hooks/*.sh .claude/verify_setup.sh
chmod +x .claude/harness/*.sh
chmod +x .claude/skills/tmux-control/scripts/tmux_control.sh
chmod +x .claude-workflow/*.sh
```

## 4) Verify offline hook behavior

```bash
bash .claude/verify_setup.sh
```

This checks:
- required files exist
- hooks are executable
- current policy docs exist under `.claude/policy/`
- `jq`, `rg`, and `realpath` are available
- standalone project skills and vendored project-scope plugins are installed under `.claude/skills/`
- `tmux-control` is installed in `.claude/skills/tmux-control/`
- Claude Code Tips is installed as `.claude/skills/dx/`, preserving its plugin namespace and repo glue files.
- Superpowers is installed as `.claude/skills/superpowers/`, preserving its plugin namespace and repo glue files.
- settings.json is advisory: `SessionStart`/`SessionEnd` only, no blocking hooks, no machine-specific absolute paths
- session bootstrap works
- the retired blocking guards and harness runner are absent
- `root-request` opens a user-owned tmux session with `sudo -i` waiting for the password, never `sudo tmux`
- `cleanup` stops only the calling Claude session's tmux sessions

## 5) Verify live Claude integration

Requires working Claude login/org entitlement. If `.claude/skills/` was created after the current Claude Code session started, restart Claude Code first.

Inside Claude Code:

- `/memory` should show the intended project `CLAUDE.md`.
- `/` should show project skills such as `tmux-control`.
- Direct project skill invocations such as `/tmux-control` should resolve.
- Plugin-scoped Claude Code Tips invocations such as `/dx:handoff` should resolve from `.claude/skills/dx/`.
- Plugin-scoped Superpowers invocations such as `/superpowers:using-superpowers` and `/superpowers:brainstorming` should resolve.
- `claude plugin list` should show `dx@skills-dir` loaded from `.claude/skills/dx/`.
- If user-scope `superpowers@claude-plugins-official` is enabled, Claude Code will use that and report the copied `.claude/skills/superpowers/` plugin as not loaded because the name is already taken.
- If `claude plugin list` says skills-dir plugins were not loaded because the workspace is not trusted, accept the workspace trust prompt in an interactive Claude Code session, then run `/reload-plugins` or restart.
- To test copied Superpowers instead of user-scope Superpowers, disable or uninstall the user-scope plugin first.

## 6) Common failure fixes

- `Your organization does not have access to Claude`:
  - run `claude auth status`
  - re-login with `claude auth login`
  - ensure org has access
- SessionStart shows only "success" without your state:
  - verify `.claude/settings.json` uses top-level `hooks` object
  - verify target run uses `--setting-sources project,local` when testing CLI

## Notes

- `.claude` contains project settings, hooks, project skills, and vendored project-scope plugins.
- `.claude/policy/` contains the current lean runtime rules and operating specification. It intentionally does not restore the old `.claude-log`, `.claude-tools`, or hash-drift runtime.
- `.claude/ENV.md` contains the default Python environment contract, and is the one file expected to be machine-specific. On a new machine, rewrite it to name that machine's activation script and environment; everything else in `.claude/` is meant to be portable as-is.
- `.claude-log` and `.claude-tools` are intentionally not part of this lean setup.
