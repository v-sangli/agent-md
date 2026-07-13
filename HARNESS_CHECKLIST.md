# Claude Workspace Harness Checklist

Purpose: keep work grounded while rebuilding the Claude Code environment. Do not make large structural edits without updating this checklist first.

## Current Goal

Set up a Claude Code workspace/harness that preserves useful behavior from the original `/home/vsangli/agent_test/.claude/` bundle while trimming failed runtime state and avoiding unnecessary scaffolding.

## Source Material

- Original bundle: `/home/vsangli/agent_test/.claude/`
- Original notes: `/home/vsangli/agent_test/Issues.txt`
- Current workspace: `/home/vsangli/agent_test/test_workspace/`
- Copied project skills and plugins:
  - `andrej-karpathy-skills` guidance is distilled into root `CLAUDE.md`.
  - `claude-code-tips` is copied as a full project-scope plugin under `.claude/skills/dx/`.
  - `superpowers` is vendored as a full project-scope plugin under `.claude/skills/superpowers/`.
- Removed references:
  - `reference/` is intentionally not part of the portable workspace.
  - Re-fetch or fork upstream third-party sources when updating copied skills.
- Official docs checked:
  - Claude Code memory / `CLAUDE.md`
  - Claude Code skills
  - Claude Code plugins
  - Claude Code hooks
  - Claude Code settings
  - Claude Code subagents

## Working Model

- `CLAUDE.md`: concise always-loaded project guidance. Context, not enforcement.
- `.claude/settings.json`: permissions and hook registration.
- `.claude/hooks/`: deterministic guardrails.
- `.claude/skills/`: standalone project skills plus project-scope plugin directories loaded on demand.
- Runtime logs and failed benchmark state are not part of the portable environment.

## Decisions

- [x] Keep project `CLAUDE.md` at repo root for now.
- [x] Keep `tmux-control` as a project skill under `.claude/skills/tmux-control/`.
- [x] Use a shell helper for tmux-control, not a Python subprocess wrapper.
- [x] Harness scripts are Bash-only. Do not add Python or embedded Python to `.claude/hooks/`, `.claude-workflow/`, verifier scripts, or other harness enforcement scripts.
- [x] Use a path-aware Bash harness runner for write/delete execution, backed by `.claude/access.conf` for local grants.
- [x] Treat direct `sudo` as a redirect to root-terminal request flow, not as an opaque-shell command.
- [x] Treat permission failures as privilege-boundary events: disclose root need, allow lesser-privilege paths only for true equivalents, and stop for root when the workaround is a compromise.
- [x] Copy selected third-party skills/plugins into `.claude/skills/` instead of keeping visible `reference/` checkouts.
- [x] Revert Superpowers from flattened project skills to a full project-scope plugin at `.claude/skills/superpowers/`.
- [x] Distill `andrej-karpathy-skills` into root `CLAUDE.md` and remove duplicate standalone `karpathy-guidelines` skill.
- [x] Uninstall user-scope `dx@ykdojo` marketplace plugin and copy local `claude-code-tips` clone as full project-scope plugin `.claude/skills/dx/`.
- [ ] Decide whether to also keep `.claude/CLAUDE.md` or use only root `CLAUDE.md`.
- [ ] Decide whether to restore `.claude/policy/` as reference docs, distilled docs, or not at all.
- [ ] Decide whether to re-enable hash-drift protection from the original bundle.
- [x] Keep an adapted `.claude-workflow/update_spec_hashes.sh` available for the current lean workspace shape.
- [ ] Decide whether any `.claude-log` style memory is worth keeping.
- [ ] Decide whether benchmark harness assets belong in this workspace or a separate fixture.

## Content To Distill From Original Bundle

Original files still available under `/home/vsangli/agent_test/.claude/`.

- [ ] Repo boundary rules.
- [ ] `.claude/**` ownership and maintainer-mode rules.
- [ ] External monkey patch / `site-packages` policy.
- [ ] One-shot patch then investigation mode.
- [ ] Verification loop and success criteria.
- [ ] Environment contract from original `ENV.md`.
- [ ] Tmux/visible execution policy.
- [ ] Sudo/root terminal policy.
- [ ] Subagent primary-model policy.
- [ ] Handoff/reset behavior.

## Skill Research

### Active / local project skills

- [x] `tmux-control`: project skill under `.claude/skills/tmux-control/`
- [x] `andrej-karpathy-skills`: distilled into root `CLAUDE.md`
- [x] `claude-code-tips`: copied as full project-scope plugin under `.claude/skills/dx/`
- [x] `superpowers`: vendored as a full project-scope plugin under `.claude/skills/superpowers/`
- [x] Preserve `superpowers:` namespace references by keeping Superpowers in plugin form.
- [x] Audit `claude-code-tips` after Superpowers revert:
  - Full repo has plugin manifest `name: dx`, root `CLAUDE.md`, root `GLOBAL-CLAUDE.md`, assets/content, and setup scripts.
  - Copied standalone skills match upstream skill folders, with local script bundling added for `clone` and `half-clone`.
  - Verified marketplace `dx@ykdojo` works, then uninstalled it to test skills-dir plugin loading.
  - Copy full local clone from `/home/vsangli/agent_test/claude-code-tips/` into `.claude/skills/dx/`, excluding `.git`.
- [x] Audit `andrej-karpathy-skills` after Superpowers revert:
  - Full repo has plugin manifest `name: andrej-karpathy-skills` and one skill, `karpathy-guidelines`.
  - Root `CLAUDE.md` is effectively the same guidance as the copied skill.
  - Remove standalone copy after appending the guidance to root `CLAUDE.md`.

### Candidate third-party skills/plugins

- [x] `andrej-karpathy-skills`
  - Plugin manifest exists.
  - Per-project `CLAUDE.md` guidance exists.
  - Distilled content in root `CLAUDE.md`: Think before coding, simplicity, surgical changes, goal-driven execution.
- [x] `claude-code-tips`
  - Plugin manifest exists.
  - Candidate skills: `handoff`, `version-check`, `clone`, `half-clone`, `gha`, `review-claudemd`.
  - Candidate `CLAUDE.md`/`GLOBAL-CLAUDE.md` patterns: concise personal/project conventions, tmux notes, handoff.
- [x] `superpowers`
  - Plugin manifest exists.
  - Large methodology system vendored locally as plugin; decide if we want its bootstrap behavior to remain active.
  - Candidate skills: `brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`, `using-git-worktrees`.
- [ ] `graphify`
  - Keep reference-only until rebuild cost and ignore behavior are measured.

## Skill Installation Questions

- [x] For current third-party skills/plugins, choose one:
  - reference-only
  - copy into `.claude/skills/`
  - symlink into `.claude/skills/`
  - install as plugin from marketplace
  - fork plugin and host our own marketplace
- [ ] Decide if modified third-party skills should live in this repo or in a forked plugin repo.
- [ ] If plugin route is chosen, document marketplace add/install/update commands.

## Hooks To Design

- [x] Route direct Bash write/delete attempts away from opaque Bash and into `.claude/harness/run.sh`.
- [x] Surface native Edit/Write/MultiEdit attempts on `.claude/**` as critical access-classifier prompts unless maintainer mode is explicitly enabled.
- [x] Redirect direct `sudo` to root-request flow.
- [x] Inject guidance after Bash privilege/permission failures.
- [x] Block direct long-running/test/install commands and point to tmux-control.
- [x] Rewrite existing active harness scripts that use embedded Python into Bash-only implementations.
- [x] Build a central Bash classifier plus a script executor for write/delete commands instead of relying on broad static Claude Code `ask` rules.
- [x] Remove static `Bash(rm -rf:*)` ask rule after the script harness can classify and execute safe deletes.
- [x] Harness decision levels:
  - `ok`: `.claude/harness/run.sh` executes workspace-scoped and safe `/tmp` writes/deletes.
  - `ask`: `.claude/harness/run.sh` stops without running and prints an approval request for writes/deletes outside the workspace or `/tmp`, unless specifically granted.
  - `critical`: `.claude/harness/run.sh` stops without running and surfaces a high-risk request with context.
- [x] Harness scope rules:
  - Allow normal file writes/deletes inside the workspace.
  - Allow `/tmp` contents to be written/deleted, but do not allow deleting `/tmp` itself.
  - Keep `.claude/**` protected except during explicit maintainer-mode work.
  - Treat external writes and deletes separately so one grant does not imply the other.
  - Treat dangerous roots such as `/`, `$HOME`, `/etc`, `/usr`, `/var`, and `/boot` as critical.
- [x] Claude Code native Edit/Write/MultiEdit cannot be script-executed by a runner; hooks can only classify and prompt/block those native tools.
- [ ] Decide whether direct `pytest` should be blocked, ask-mode, or allowed for short tests.
- [x] Use structured JSON permission decisions for access-guard `allow`/`ask` and critical prompts; keep exit-code blocks for direct sudo and tmux-required commands.
- [ ] Add tests for quoted `sudo` inside root-request command.
- [ ] Add tests for shell edge cases: `env sudo`, `command sudo`, `doas`, `su -c`.

## Environment Handling

- [ ] Distill original `.claude/policy/ENV.md`.
- [ ] Decide what belongs in `CLAUDE.md` vs `.claude/settings.json` `env` vs `.claude/settings.local.json`.
- [ ] Keep secrets and machine-specific paths local-only.

## Benchmark / Harness Issues

- [ ] Preserve BugsInPy fixture knowledge somewhere if still useful.
- [ ] Do not preserve failed `.claude-log` state.
- [ ] Define benchmark question schema:
  - setup command
  - expected failure signature
  - patch workspace
  - rerun command
  - success criteria
  - transcript/diff capture location
- [ ] Decide whether benchmark runners belong inside `.claude/skills/`, `.claude/commands/`, separate `harness/`, or external repo.

## Known Complaints To Resolve

- [ ] Direct sudo prompt can hang invisibly.
- [ ] Long-running commands need visible/persistent execution.
- [ ] Need handoff/reset strategy.
- [ ] Need subagent model policy.
- [ ] Need skill installation/update story.
- [ ] Need concise `CLAUDE.md` that retains important original policy without bloat.
- [ ] Need clear portable setup.
- [ ] Need repeatable verifier.
- [x] Existing active harness scripts no longer contain embedded Python.
- [x] Need path-aware write/delete harness execution so safe workspace cleanup is smooth and external/destructive actions are visible.

## Validation Checklist

- [ ] `/memory` shows intended `CLAUDE.md`.
- [ ] `/` menu shows intended project skills.
- [ ] `/` menu shows intended project-scope plugin skills such as `dx:handoff`.
- [ ] `/` menu shows intended project-scope plugin skills such as `superpowers:using-superpowers`.
- [ ] Direct skill invocations work after restarting Claude Code if `.claude/skills/` was created during an existing session.
- [ ] Copied standalone project skills and vendored skills-dir plugins are both understood.
- [ ] Accept workspace trust and run `/reload-plugins` so `superpowers@skills-dir` loads from `.claude/skills/superpowers/`.
- [x] Confirm `dx@skills-dir` is detected and loaded from `.claude/skills/dx/`.
- [ ] Decide whether to disable user-scope `superpowers@claude-plugins-official`; current Claude Code precedence prevents copied `superpowers@skills-dir` from loading while the user-scope plugin is enabled.
- [x] Direct `sudo true` redirects to root-request.
- [x] Bash permission/privilege failure injects root-request guidance.
- [x] Direct Bash attempts to mutate files are blocked and routed to `.claude/harness/run.sh`.
- [x] Bash attempts to mutate `.claude/**` are blocked directly and surfaced as critical non-running requests through the harness.
- [x] Workspace-scoped `rm -rf` executes only through `.claude/harness/run.sh`, without static Claude Code ask.
- [x] `/tmp` content cleanup executes only through `.claude/harness/run.sh`, but deleting `/tmp` itself is critical and non-running.
- [x] External write/delete is classified as `ask` unless an explicit access grant allows it.
- [x] Critical destructive commands are surfaced to the user with context and do not run.
- [x] Root-request command is allowed by hook even when `--command` contains `sudo`.
- [x] Direct long-running/test command gives tmux-control redirect.
- [ ] tmux-control smoke starts, sends, captures, and cleans up a session.
- [x] `verify_setup.sh` passes.
- [ ] Bundle/install instructions reproduce the setup in a fresh directory.
