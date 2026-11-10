# Harness Checklist

Decision log for changes to the Claude Code harness (`.claude/` hooks, skills, policy).
Per `CLAUDE.md`: check this file before changing harness structure and record the
decision being made. Run `bash .claude/verify_setup.sh` after every harness change.

## Decisions

### 2026-11-09 — merge man_agent-md variant; opus subagents; tmux root flow + cleanup
- **Problem:** `man_agent-md.zip` (2026-10-19, another machine's copy) carried
  rules the template lacked: worktrees default off, `worktree.bgIsolation:
  "none"`, no commits unless asked, no `$(...)` in shell commands. Its skills,
  hooks, and policy were otherwise identical; its `settings.local.json` and
  sandbox-path bullet were machine-specific. Separately: superpowers SDD tiered
  subagent models by difficulty, and cheaper first attempts cost more debugging;
  agents forgot the root tmux path existed; `root-request` told users to run
  `sudo tmux new-session`, which starts a root-owned tmux server the agent
  cannot reach; agents left sessions open, accumulating dozens over time.
- **Decision (owner-directed):** merge the zip's generic `CLAUDE.md` sections
  and `bgIsolation` setting (machine paths dropped). SDD Model Selection and
  prompt templates now say `model: opus` for every role; `CLAUDE.md` restates
  it. `root-request` now creates a user-owned session and types `sudo -i` into
  the pane; the agent `wait`s for `^root@` before sending anything. Root tmux is
  the first-offered option in `AGENT_RULES.md`, `CLAUDE.md`, and the
  SessionStart reminder. `start` tags sessions with `@claude_session =
  $CLAUDE_CODE_SESSION_ID`; new `stop` and `cleanup` (own, non-`--keep`
  sessions only); a `SessionEnd` hook runs `cleanup --idle-only` as a safety
  net, sparing panes running a non-shell process because `claude -p
  --continue` ends a session every turn.
- **Verify:** `bash .claude/verify_setup.sh`; new checks cover the root flow
  (user-owned, `sudo -i`, no `sudo tmux`) and owner-scoped cleanup. Hook tested
  by hand: idle own session reaped, busy own session kept.

### 2026-08-12 — formalize the template: delete retired code, enforce portability
- **Problem:** `agent-md` had not been synced since 2026-07-18, so the template
  still shipped the blocking model the workspace abandoned on 07-26. Reviewing
  the 08-04..08-12 sessions surfaced three live costs: 14 `File has not been
  read yet` rejections from writing before reading; 3 `no aliases recorded for
  session` failures in a run with 36 tmux calls; 2 blocked `sleep` polls. The
  tmux failure was the same class of bug as the one that killed the hooks —
  `tmux_control.sh` defaulted its state dir to a *relative* `.tmux-control`, so
  when the shell cwd drifted between calls, `capture` looked for the alias file
  in a directory `start` never wrote to.
- **Decision (owner-directed):** `agent-md` is a general template, not a
  snapshot of this machine. Only `.claude/ENV.md` may name a specific
  environment; everything else resolves through `$CLAUDE_PROJECT_DIR` or a
  relative path, and `verify_setup.sh` now fails on any other absolute
  `/home/…`/`/Users/…` reference (vendored plugins and `settings.local.json`
  excluded). Accordingly: anchor the tmux state dir to `$CLAUDE_PROJECT_DIR`;
  delete the retired guards, `harness/run.sh`, and `access.conf` outright
  (absence now asserted) along with the context engine, which native context
  management and the `dx` skills have superseded; generalize the ENV/env-name
  references out of `verify_setup.sh`, `AGENT_RULES.md`, `PORTABLE_SETUP.md`,
  and `tmux-control/references/validation.md`; add two rules earned from the
  session review — `Read` before `Write`/`Edit`, and no foreground `sleep`
  polling. Fixed two broken commands in `ENV.md` (home conda pointed at the
  workspace path under the wrong env name) and restored its worktree note.
- **Verify:** `bash .claude/verify_setup.sh` — 54 PASS / 0 FAIL. tmux cwd-drift
  fix regression-tested directly: `start` from `/tmp` then `capture` from
  `~` succeeds with the anchor and reproduces `no aliases recorded` without it.

### 2026-07-19 — access_guard: /dev/null sinks are not write actions
- **Problem:** `pre_tool_use_bash_guard.sh` blocks on any non-empty access-guard
  decision. `access_guard.sh` classified `/dev/null` redirect targets as `ok`
  ("null sink") but still counted them as actions, so purely read-only commands
  carrying `2>/dev/null` emitted an all-ok decision and got blocked.
- **Decision (owner-approved):** in `classify_target`, resolve the target first and
  return before incrementing `action_count` when it resolves to `/dev/null`.
  Discarding output is not a write. Real write/delete targets keep the existing
  behavior: workspace writes still emit a decision, so direct-Bash writes still
  route through `.claude/harness/run.sh`; ask/critical classifications unchanged.
- **Verify:** `bash .claude/verify_setup.sh` + synthetic-payload checks
  (read+`2>/dev/null` → no decision; workspace write → ok decision; `/etc` delete
  → critical decision).

### 2026-07-26 — rollback: retire blocking enforcement, go advisory (spec 3.0)
- **Problem:** hooks were registered with relative paths and run in the
  session's cwd; when the persistent shell cwd drifted (e.g. into
  `openmimic/`), every hook failed non-blocking — enforcement silently
  disappeared while tools kept running, with zero visibility. Working around
  path issues accumulated machine-specific absolute paths in `settings.json`.
  Prompt/block friction outweighed protection.
- **Decision (owner-directed):** give up blocking. `settings.json` now
  registers only SessionStart (via `$CLAUDE_PROJECT_DIR`, cwd-proof); the
  access guard, bash guard, privilege guard, and harness runner are
  unregistered (scripts left on disk as retired). Permissions: broad allow
  (`Read`/`Edit`/`Write`/`MultiEdit`/`Bash`/web), `ask` kept for `git push`,
  `git reset --hard`, `sudo`. All tmux-control restrictions demoted to
  suggestions/encouragements in `AGENT_RULES.md` (now "Conventions") and
  `OPERATING_SPEC.md` 3.0. `access.conf` retired. No absolute paths in
  `settings.json` — verify enforces this.
- **Verify:** `bash .claude/verify_setup.sh` (pruned to advisory contract) — 0 FAIL.

### 2026-07-24 — verify_setup: drop stale checks (dexpolicy env, reference/)
- **Problem:** with ripgrep installed, verify surfaced two stale expectations:
  ENV.md check required old `source ~/miniconda3/bin/activate dexpolicy` line
  (contract now points at in-workspace conda, env `hssim`), and `reference/` was
  on the must-be-absent list but now holds intentional read-only checkouts
  (holosoma, MimicKit, GR00T-VisualSim2Real).
- **Decision (owner-approved):** update env-contract required string to
  `source ~/sim-project_v3/.holosoma_deps/miniconda3/bin/activate hssim`; remove
  `need_absent "reference"`. Checks now match the current contract.
- **Verify:** `bash .claude/verify_setup.sh` — expect 0 FAIL.

### 2026-07-24 — permissions: cwd-proof tmux_control.sh invocation
- **Problem:** allow rule for the helper was relative-prefix only. After a `cd`
  moved the persistent shell cwd, relative invocation hit exit 127 (script not
  found) and absolute-path or `cd <root> &&` invocations prompted for approval.
  Helper also resolves session state from cwd's `.tmux-control/`, so calls must
  be anchored at the workspace root anyway.
- **Decision (owner-approved):** add two allow rules: absolute-path helper
  invocation, and `cd /home/vsangli/sim-project_v3` so the canonical form
  `cd /home/vsangli/sim-project_v3 && .claude/skills/tmux-control/scripts/tmux_control.sh ...`
  passes without prompting. Bash-guard hook already matches all forms
  (substring match). No script changes.
- **Verify:** `bash .claude/verify_setup.sh`.

### 2026-07-24 — permissions: allow raw `tmux capture-pane`
- **Problem:** Monitor/poll loops embedding raw `tmux capture-pane` prompted for
  approval — allowlist only trusted the `tmux_control.sh` wrapper, and the `tmux`
  binary is not classified read-only (same binary does `send-keys`,
  `kill-session`).
- **Decision (owner-approved):** add `Bash(tmux capture-pane:*)` to
  `settings.json` allow. `capture-pane` mutates nothing; risk is limited to
  reading pane contents, acceptable in this workspace. Belt-and-suspenders:
  prefer wrapper `capture`/`wait` subcommands for standard workflows; raw
  capture-pane rule covers ad-hoc Monitor loops. All other raw tmux subcommands
  still prompt.
- **Verify:** `bash .claude/verify_setup.sh`.

### 2026-07-19 — tmux-control: add `wait` subcommand
- **Problem:** no blocking "return when the run finishes" method existed
  (subcommands were start/send/capture/status/interrupt/root-request); completion
  watching required hand-rolled polling loops through the harness.
- **Decision (owner-approved):** add `wait (--target SESSION::ALIAS | --log FILE)
  --pattern REGEX [--timeout SECS] [--interval SECS]` — polls the durable log (or
  pane capture as fallback) until the regex matches; exit 0 on match, 1 on
  timeout. Long waits should still be invoked via background execution so the
  agent is re-notified instead of holding a foreground shell.
