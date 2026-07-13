# Claude Operating Specification

Version: 2.1
Scope: Current lean Claude Code workspace/harness in this repository.

`AGENT_RULES.md` is the canonical rule source. This file explains how the
workspace is structured, why the rules exist, and how to verify the setup. If a
short rule and this document drift, update both deliberately instead of treating
this file as an additional rule layer.

## 1. File Roles

```text
CLAUDE.md                         always-loaded orientation and style
.claude/policy/AGENT_RULES.md     concise canonical runtime contract
.claude/policy/OPERATING_SPEC.md  rationale, design notes, acceptance criteria
.claude/ENV.md                    environment identity and activation commands
.claude/settings.json             Claude Code hook/permission registration
.claude/hooks/                    enforcement and redirect messages
.claude/harness/run.sh            shell write/delete executor
.claude/access.conf               local access grants
.claude/skills/tmux-control/      visible shell/root workflow helper
.claude/skills/dx/                vendored Claude Code Tips plugin
.claude/skills/superpowers/       vendored Superpowers plugin
```

Policy hash drift blocking is not active unless explicitly reintroduced and
documented in `HARNESS_CHECKLIST.md`.

## 2. Access Model

Normal repository files are the default working area. `.claude/**` is protected
configuration, but can be edited during explicit harness maintenance like this
current setup work.

The active access path is:

1. Claude attempts a Bash write/delete.
2. `.claude/hooks/pre_tool_use_bash_guard.sh` blocks direct mutation and points
   to `.claude/harness/run.sh`.
3. `.claude/harness/run.sh` asks `.claude/hooks/access_guard.sh` to classify
   every target.
4. Workspace and safe `/tmp` content writes/deletes run; external targets ask;
   critical targets do not run.
5. `.claude/access.conf` can grant external write/delete roots or protected
   `.claude/**` maintainer mode.

Native `Edit`, `Write`, and `MultiEdit` tools cannot be script-executed by the
harness, so hooks classify and prompt/block them directly.

## 3. Shell And Tmux Routing

Direct Bash is kept for short read-only inspection because it is fast and easy
to audit. Anything with progress, prompts, credentials, installation, tests, or
long runtime moves to `tmux-control`, where the user can attach and observe.

This is intentionally a routing rule, not a claim that every test is dangerous.
The current harness chooses transparency over convenience for direct test/build
commands. Revisit this in `HARNESS_CHECKLIST.md` if short direct tests should be
allowed later.

## 4. Privilege Boundary

The sudo/root rule exists because Claude Code's opaque shell cannot reliably
surface password prompts. The desired behavior is:

1. disclose that elevated privilege appears to be the direct path;
2. provide any cheap no-root information that is genuinely equivalent or useful;
3. avoid building on a partial workaround;
4. request a visible root tmux session through `tmux-control` when privilege is
   necessary.

The hook and skill messages are operational copies of this route. They should
stay short and should point back to the canonical rule when possible.

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
3. `AGENT_RULES.md` is the only concise canonical runtime contract.
4. `OPERATING_SPEC.md` explains design/rationale without becoming a second
   stronger rule layer.
5. Direct Bash writes/deletes route to `.claude/harness/run.sh`.
6. External writes/deletes ask unless granted in `.claude/access.conf`.
7. Critical destructive requests stop without running.
8. Direct sudo and in-session sudo suggestions route to root tmux request flow.
9. Direct tests/installs/builds/benchmarks route to `tmux-control`.
10. Environment details live in `.claude/ENV.md`.

## 10. Maintenance Procedure

When updating this harness intentionally:

1. Update `HARNESS_CHECKLIST.md` with the decision being made.
2. Keep active scripts Bash-only.
3. Prefer editing the canonical source over repeating a rule in more files.
4. Run `bash .claude/verify_setup.sh`.
5. Review `git diff` before committing.
