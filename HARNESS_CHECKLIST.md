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
- `.claude/policy/`: current lean runtime rules and operating specification, adapted from the original bundle.
- `.claude/skills/`: standalone project skills plus project-scope plugin directories loaded on demand.
- Runtime logs and failed benchmark state are not part of the portable environment.

## Decisions

- [ ] Context engine: build per `CONTEXT_ENGINE_PLAN.md` (bash+jq tooling under `.claude/context/`, Stop-hook gauge, offline `ctxprune` clone, auto-resume supervisor). Grounded in `CONTEXT_FORENSICS.md`; `ctxprune` never edits live transcripts. Not yet executed.
- [x] Keep project `CLAUDE.md` at repo root for now.
- [x] Use concise-vs-elaborate rule layering: `AGENT_RULES.md` is canonical, `OPERATING_SPEC.md` explains, `CLAUDE.md`/session-start point to sources, and domain files carry mechanics.
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
- [x] Restore `.claude/policy/` as current distilled policy docs, not legacy runtime scaffolding.
- [ ] Decide whether to re-enable hash-drift protection from the original bundle.
- [x] Keep an adapted `.claude-workflow/update_spec_hashes.sh` available for the current lean workspace shape.
- [ ] Decide whether any `.claude-log` style memory is worth keeping.
- [ ] Decide whether benchmark harness assets belong in this workspace or a separate fixture.
- [x] pip is routed by subcommand (git precedent, zero content parsing): `show`/`list`/`freeze`/`check`/`inspect`/`debug`/`help` run inline; `install`/`uninstall`/`download`/everything env-mutating stays on tmux. Blanket reroute rejected: the read-only queries have none of the blocking/opaque properties that make tmux valuable for installs.
- [x] PYTHONPATH policy loosened to judgment (AGENT_RULES §4): the shared conda env is stable infrastructure; a one-shot `PYTHONPATH=<src>` scoped to a test invocation is fine for exercising unmerged/worktree code, but is not a durable substitute for a real install. Durable env mutations (installs, upgrades, editable repoints) stay ask-gated, with a `pip install --dry-run` resolver check recommended first. AGENT_RULES §2 also updated to describe the shipped single-decider routing (it still described the pre-refactor "all shell writes via run.sh" world). `python -V/--version`, any `python -c <code>` one-liner, and `source <...>/bin/activate ENV` classify clean; `python script.py`, `python -m <mod>`, bare REPLs, pytest/pip/cargo/`maturin` still route to tmux. Rationale: duration is not a syntactic property — a first attempt at an import-only `-c` grammar denied natural probes (`print('prefix', sys.prefix)`) while adding ~no safety under this workspace's declared transparency posture. A `-c` one-liner is visible in the transcript and bounded by the Bash tool's 2-minute timeout; anything longer must go to tmux anyway. Accepted tradeoff (same class as the native awk/sed/find allowlist): a one-liner *could* write externally without an ask — the access.conf sandbox gates shell-level writes, not interpreter-mediated ones, and tmux-routed commands were never write-gated either. If hard containment is ever wanted, that's a different posture than this workspace chose.
- [x] `.claude/ENV.md` corrected: the conda root is `/data/miniconda3` (`~/miniconda3` does not exist on this machine — probe-verified 2026-07-14); verify assertion updated to match.
- [x] Tokenizer hardening (fail-open fixes): newline and lone `&` are command separators (previously whitespace/token-glue, so `ls`⏎`rm -rf X` scanned `rm` as an argument of `ls` and could auto-allow); word-initial unquoted `#` starts a comment consumed to end of line; `2>&1` is one `>&` fd-dup token.
- [x] Variable-alias head resolution: leading `VAR=value` assignments are recorded and a later `"$VAR"` head resolves to the literal (the `TC=.../tmux_control.sh` idiom). Resolved *mutators* are never clean (access_guard scans only unexpanded tokens), and a dynamic reassignment forgets the name.
- [x] Quote-aware substitution policy: unquoted `$(...)` is segmented, so inner heads and write targets are fully scanned (poll loops like `out=$("$TC" capture ...)` classify normally); double-quoted `"$(...)"` and backticks hide execution from the token scan and stay opaque → native ask. `seq`/`sleep`/`break`/`continue` are safe heads; `timeout` is head-transparent.
- [x] tmux-control gained `wait-for --target --pattern [--timeout --interval --lines]` as the sanctioned replacement for hand-rolled poll loops (documented in references/commands.md).
- [x] Make `pre_tool_use_bash_guard.sh` the single decider: it emits explicit `permissionDecision` JSON instead of exit-2 blocks and silent pass-throughs. `allow` for statically-clean commands whose writes stay in workspace//tmp/granted roots (bypasses the native engine's compound-command asks: "shell operators", "simple_expansion", "cd before git"); `ask` with reason for external writes (grant a root in `.claude/access.conf` to silence); `deny` with redirect text for sudo (root-request) and interpreters (tmux); **no output** for anything not statically classifiable (`$(...)`, backticks, eval, unknown heads, `git push`/`git reset`) so the native engine still asks — fail-safe, never fail-open. Cleanliness lives in `cs_decide` in `hooks/lib/command_scan.sh`; awk/sed are treated as safe for parity with the existing native allowlist. A dead hook now degrades to *more* asking (native-only), not less guarding.
- [x] Register all hooks with `$CLAUDE_PROJECT_DIR`-absolute commands. Relative `bash .claude/hooks/...` registrations broke silently (non-blocking "No such file or directory") whenever a persisted `cd` moved the shell CWD out of the workspace, leaving Bash calls unguarded. `verify_setup.sh` now asserts the absolute form. Registration changes take effect on session restart (hook config is snapshotted at startup; script *contents* are read fresh per call).
- [x] Normalize guard roots with `pwd -P`. The workspace is reachable via twin spellings (`/home/vsangli/workspace` is a symlink to `/data/workspace`); comparing realpath-resolved targets against a logical root misclassified workspace writes as external (masked only while `access.conf` grants all external writes).
- [x] Scope `post_tool_use_privilege_guard` to error/stderr text only. Grepping every payload string (including stdout) made reading any file that merely contains "Operation not permitted" fire the privilege advisory.
- [x] Classify Bash commands by the command *head* of each pipeline segment, not by substring matches on the whole command string. Route only genuine interpreters/tests/installs/builds (and the inner command of `bash -c`) to tmux, and only genuine writes/deletes *outside* the whitelist (workspace + `/tmp`) to the access harness. Whitelist-dir writes and discarded sinks (`/dev/null` etc.) run free. Shared logic lives in `.claude/hooks/lib/command_scan.sh`, sourced by `access_guard.sh`, `pre_tool_use_bash_guard.sh`, and `harness/run.sh` (single source, no divergent regexes). Rationale: the prior whole-string regex + "any access-guard output blocks" model false-blocked read-only commands (`which bun`, `ls | grep npm`, `cat x 2>/dev/null`) and one-shot `bash -c`. This turns a blanket ask into a filtered ask; the external-write sandbox toggle in `.claude/access.conf` is unchanged.
- [x] Ask-friction teardown, minimal form (2026-07-15). Transcript replay showed the prompt storm had two distinct sources, fixed separately: (1) commands the guard already *falls through on* (`"$(...)"`, mutating git subcommands, complex `bash -c`, `$VAR`-alias pipelines) were being asked about by the **native engine** because the allowlist was prefix-only — fixed by adding bare `Bash` to `permissions.allow` (the three native asks `git push`/`git reset --hard`/`sudo` are rule-matched and unaffected); (2) the guard's own ask on **dynamic-only write targets** (`$broken` from mktemp, `$REPO/$f` loops) — fixed in `pre_tool_use_bash_guard.sh` only: when *every* ASK finding is `(dynamic or unresolved path)`, emit nothing (fall through to native, where bare `Bash` allows); any resolved external target still asks, and CRITICAL asks are untouched. Accepted tradeoff: a dangerous `rm -rf "$TARGET"` is statically indistinguishable from a safe scratch var and now runs without an ask. Both guards remain registered; sudo→root-request and interpreter→tmux redirects verified unchanged; `access_guard.sh`, `command_scan.sh`, and `run.sh` untouched. Rejected on the way (2026-07-15): full guard unregistration plus policy-doc rewrite — reverted byte-identical; AGENT_RULES/OPERATING_SPEC stay canonical as written, and rule changes require explicit discussion first. Cleanup in the same pass: the session-local `access.conf` blanket grants (`allow_external_write/delete=true`, `maintainer_mode=true`) are restored to `false` — the friction they papered over is fixed at the source, and they were silencing `.claude/**` CRITICAL protection and the run.sh approval path; `spec_hashes.json` stays absent per the lean-harness posture (do not regenerate); the stale `need_absent "reference"` verify line is removed (the live workspace has carried an active `reference/` repos dir since May).
- [x] tmux-control gained `run` (2026-07-15, from worktree-session friction report ranked: poll boilerplate 80%, quoting, capture noise): one call = send + sentinel completion-wait + run-scoped capture slice + exit-code propagation (124 on timeout). BEGIN/DONE markers are quote-split in the typed line so the echoed command can't false-match the anchored patterns; the payload runfile is *sourced* in the pane shell so env activation persists across runs (the one-session-per-workstream pattern the report endorsed); auto-capture to `.tmux-control/captures/<ts>-<label>.log` + `.ec`. Multi-line payloads via `--command -` on stdin (kills a quoting layer). Live-smoked 5/5: success slice, failure ec + stale-scrollback exclusion, multi-line python-heredoc via stdin, timeout→124 with pane survival, post-interrupt reuse. Interpreter hard-deny itself: unchanged pending the alternatives discussion (rules discuss-first); the ergonomics fix attacks the cost side of that tradeoff.

## Content To Distill From Original Bundle

Original files still available under `/home/vsangli/agent_test/.claude/`.

- [x] Repo boundary rules.
- [x] `.claude/**` ownership and maintainer-mode rules.
- [x] External monkey patch / `site-packages` policy.
- [x] One-shot patch then investigation mode.
- [x] Verification loop and success criteria.
- [x] Environment contract from original `ENV.md`.
- [x] Tmux/visible execution policy.
- [x] Sudo/root terminal policy.
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
- [x] Disallow in-session `! sudo` and user-run/paste-output sudo as suggested paths; privileged continuation must use an approved visible root tmux session.
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
- [x] Route direct `pytest`/test/build/install commands through `tmux-control` for now; revisit later if short direct tests should be allowed.
- [x] Use structured JSON permission decisions for access-guard `allow`/`ask` and critical prompts; keep exit-code blocks for direct sudo and tmux-required commands.
- [ ] Add tests for quoted `sudo` inside root-request command.
- [ ] Add tests for shell edge cases: `env sudo`, `command sudo`, `doas`, `su -c`.

## Environment Handling

- [x] Distill original `.claude/policy/ENV.md` into `.claude/ENV.md` plus a concise root `CLAUDE.md` reminder.
- [x] Decide what belongs in `CLAUDE.md` vs `.claude/settings.json` `env` vs `.claude/settings.local.json`.
  - Keep the environment contract in `.claude/ENV.md`.
  - Keep always-loaded behavioral reminders in root `CLAUDE.md` and `session_start.sh`.
  - Do not encode conda activation in `.claude/settings.json` `env`; activation is shell state, not simple environment variables.
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

- [x] Direct sudo prompt can hang invisibly.
- [ ] Long-running commands need visible/persistent execution.
- [ ] Need handoff/reset strategy.
- [ ] Need subagent model policy.
- [ ] Need skill installation/update story.
- [x] Need concise `CLAUDE.md` that retains important original policy without bloat.
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
- [x] Direct Bash writes/deletes *outside* the whitelist (workspace + `/tmp`) surface as a native ask carrying the guard's reason and the `.claude/access.conf` grant hint; whitelist-dir writes run promptless (filtered, not blanket). `.claude/harness/run.sh` remains available as a manual utility.
- [x] Bash attempts to mutate `.claude/**` surface as CRITICAL asks (approvable), or run under `maintainer_mode=true`.
- [x] Read-only compounds (pipes, `&&`, loops, `$VAR` args, discarded redirects, `git -C` read-only subcommands) run promptless via guard `allow` — live-verified in-session.
- [x] Dynamic constructs (`$(...)`, backticks, eval, unknown heads) and `git push`/`git reset` fall through to native asks.
- [x] Whitelist-dir `rm -rf` / redirects / `sed -i` run directly without routing or static ask.
- [x] Read-only commands are never routed: discarded redirects (`... 2>/dev/null`), interpreter names as arguments (`which bun`, `command -v bun`, `ls | grep npm`), and one-shot `bash -c 'echo ...'` all run directly; `bash -c 'pytest ...'` still routes to tmux.
- [x] `/tmp` content cleanup executes only through `.claude/harness/run.sh`, but deleting `/tmp` itself is critical and non-running.
- [x] External write/delete is classified as `ask` unless an explicit access grant allows it.
- [x] Critical destructive commands are surfaced to the user with context and do not run.
- [x] Root-request command is allowed by hook even when `--command` contains `sudo`.
- [x] Direct long-running/test command gives tmux-control redirect.
- [ ] tmux-control smoke starts, sends, captures, and cleans up a session.
- [x] `verify_setup.sh` passes.
- [ ] Bundle/install instructions reproduce the setup in a fresh directory.
