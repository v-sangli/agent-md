# Claude Operating Specification

Version: 3.0
Scope: Current advisory Claude Code workspace/harness in this repository.

`AGENT_RULES.md` is the canonical rule source. This file explains how the
workspace is structured, why the rules exist, and how to verify the setup. If a
short rule and this document drift, update both deliberately instead of treating
this file as an additional rule layer.

## 0. The 3.0 Rollback

Versions up to 2.1 enforced the contract with blocking PreToolUse/PostToolUse
hooks (`access_guard.sh`, `pre_tool_use_bash_guard.sh`,
`post_tool_use_privilege_guard.sh`) and a shell-write executor
(`.claude/harness/run.sh`). That model was retired on 2026-07-26:

- Hook commands were registered with relative paths and run in the session's
  current working directory. When the persistent shell cwd drifted out of the
  workspace, every hook failed non-blocking — enforcement silently vanished
  while tools kept running.
- Working around it accumulated machine-specific absolute paths in
  `settings.json` and permission rules, which defeated portability.
- The prompt/block friction outweighed the protection: the model's actual
  failure modes were path/cwd bugs, not destructive intent.

The replacement model is advisory: `AGENT_RULES.md` states conventions, the
`tmux-control` skill remains the encouraged route for visible/long-running
work, and Claude Code's native permission `ask` list covers the few genuinely
dangerous operations (git push, hard reset, sudo). No tool calls are blocked.

## 1. File Roles

```text
CLAUDE.md                         always-loaded orientation and style
.claude/policy/AGENT_RULES.md     concise canonical runtime contract (advisory)
.claude/policy/OPERATING_SPEC.md  rationale, design notes, acceptance criteria
.claude/ENV.md                    environment identity and activation commands
.claude/settings.json             SessionStart hook + broad permission grants
.claude/hooks/session_start.sh    state reinjection at session start
.claude/skills/tmux-control/      visible shell/root workflow helper
.claude/skills/dx/                vendored Claude Code Tips plugin
.claude/skills/superpowers/       vendored Superpowers plugin
```

Deleted on 2026-08-12: `.claude/hooks/access_guard.sh`,
`.claude/hooks/pre_tool_use_guard.sh`, `.claude/hooks/pre_tool_use_bash_guard.sh`,
`.claude/hooks/post_tool_use_privilege_guard.sh`, `.claude/harness/run.sh`,
`.claude/access.conf`. They had been unregistered since the rollback; the
rationale above is the record, and `verify_setup.sh` asserts their absence.

## 2. Access Model

Normal repository files are the default working area. Writes and deletes stay
inside the workspace by convention; external scope needs the user's go-ahead in
conversation, not a config grant. `.claude/**` is setup configuration — edited
during harness maintenance, left alone during ordinary tasks.

Claude Code native permissions carry the remaining hard edges: `git push`,
`git reset --hard`, and `sudo` sit on the `ask` list; everything else is
allowed. Keep permission rules relative or tool-level — no machine-specific
absolute paths in `settings.json`.

## 3. Shell And Tmux Routing

Direct Bash is allowed for everything. `tmux-control` stays the recommended
route for anything with progress, prompts, credentials, installation, tests, or
long runtime, because the user can attach, observe, and interrupt, and the
durable capture log survives the session. This is a recommendation on grounds
of transparency, not a gate.

Practical cwd rule: the persistent shell's cwd drifts across Bash calls. Invoke
helper scripts by absolute path or prefix with `cd` to the workspace root.

## 4. Privilege Boundary

The sudo guidance exists because Claude Code's opaque shell cannot reliably
surface password prompts. The desired behavior is:

1. disclose that elevated privilege appears to be the direct path;
2. provide any cheap no-root information that is genuinely equivalent or useful;
3. avoid building on a partial workaround;
4. offer the visible root tmux session through `tmux-control` first whenever
   privilege is necessary. The session stays user-owned and escalates in-pane
   with `sudo -i`; a `sudo tmux` server would be root-owned and unreachable by
   the agent.

## 5. Environment Boundary

`.claude/ENV.md` identifies the default conda environment and validation
commands. Behavioral constraints such as avoiding durable `PYTHONPATH=.`
workarounds live in `AGENT_RULES.md` so environment details do not become a
second policy file.

Conda activation is shell state, so it is not encoded in `.claude/settings.json`
`env`.

## 6. Change Discipline

The harness keeps the useful parts of the original operating spec:

- one minimal patch before investigation mode;
- no unapproved external monkey patches;
- prefer existing modules/helpers over parallel systems;
- propose subsystem refactors first;
- define success criteria and run meaningful validation.

These are judgment rules. They should guide behavior without turning every task
into ceremony.

## 7. Skills And Plugins

`tmux-control` is a standalone project skill because it is part of this harness.
`dx` and `superpowers` are copied as complete project-scope plugin directories
because their repo-level glue files matter. Avoid flattening third-party plugin
repos unless the loss of their root metadata is intentional and documented.

## 8. Portability

`.claude/PORTABLE_SETUP.md` describes bundle/install/chmod/verify steps.
`.claude-workflow/bundle_claude_dirs.sh` should package `CLAUDE.md`, `.claude/`,
and `.claude-workflow/`. Generated runtime state stays out of the portable
bundle unless explicitly requested.

## 9. Acceptance Criteria

Setup is considered correct when all are true:

1. `bash .claude/verify_setup.sh` passes.
2. `CLAUDE.md` points to the policy and environment sources instead of
   restating every hard rule.
3. `AGENT_RULES.md` is the only concise canonical runtime contract, and it is
   advisory — no blocking hooks are registered.
4. `OPERATING_SPEC.md` explains design/rationale without becoming a second
   stronger rule layer.
5. `settings.json` registers only the SessionStart hook, allows tools broadly,
   and contains no machine-specific absolute paths.
6. `git push`, `git reset --hard`, and `sudo` remain on the permissions `ask`
   list.
7. Environment details live in `.claude/ENV.md`.

## 10. Maintenance Procedure

When updating this harness intentionally:

1. Update `HARNESS_CHECKLIST.md` with the decision being made.
2. Keep active scripts Bash-only.
3. Prefer editing the canonical source over repeating a rule in more files.
4. Run `bash .claude/verify_setup.sh`.
5. Review `git diff` before committing.
