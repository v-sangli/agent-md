# Claude Operating Specification

Version: 3.1
Scope: Current advisory Claude Code workspace/harness in this repository.

`CLAUDE.md` is the canonical rule source. This file explains how the
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

The replacement model is advisory: `CLAUDE.md` states conventions, the
`tmux-control` skill remains the encouraged route for visible/long-running
work, and Claude Code's native permission `ask` list covers the few genuinely
dangerous operations (git push, hard reset, sudo). No tool calls are blocked.

## 0.1 The 3.1 Restructure

On 2026-11-13 the harness was reshaped around an agreed design methodology. The
enforcement model is unchanged: advisory text and the user's gates on the agent
side; mechanical checks belong to each repo's CI and branch protection, not to
hooks here. What changed is where things live. Three homes, split by the kind of
statement:

- `CLAUDE.md` holds what binds any code that gets written: the code stance,
  the red-test verdict, the isolation rules and gates, the runtime conventions.
  It is always in context, for the subagents that write code too (the built-in
  Explore and Plan agents are the exception), so it is the only home for a rule
  that constrains code. It stays under 200 lines; the verifier checks that.
- `.claude/skills/dev-flow/` holds the order of work for a code change, from
  request to merge. Each step establishes its concept: what it is for, what it
  produces, who confirms it. `SKILL.md` carries every definition; its reference
  files hold worked examples and templates only.
- The vendored `superpowers` skills hold the technique for one step. Each skill
  used to require the next; those hand-offs now return to `dev-flow`.

The test for every text is coverage: a concept the harness uses is either
generally known, and then it is named with only our additions stated, or it is
ours, and then it is established where a fresh session reads it.

The template is environment-neutral. `CLAUDE.md` names no host, machine path
or repo. One machine's own rules live in `CLAUDE.local.md` at the workspace
root, which Claude Code loads alongside `CLAUDE.md`; it is not bundled or
synced. `.claude/ENV.md` remains the one template file that is rewritten per
machine.

How the text is edited:

- A rule is written once, in its home.
- A line that says the opposite is edited or deleted in the same commit.
  Nothing is overridden from elsewhere. The former `CLAUDE.md` block that
  declared itself an override of any skill is gone, together with the "default
  off" worktree rule and the "do not commit unless asked" rule it carried.
- A skill may name a rule at the moment it applies, in one line. It does not
  restate it.

## 0.2 Porting 3.1 Onto the Template

The 3.1 restructure was written on another machine, on top of that machine's
copy of the harness, which predated the template's 2026-11-09 changes. On
2026-11-14 it was ported onto the template. Where the two disagreed:

- Isolation and gates (worktrees by default, commits on the feature branch)
  come from 3.1, as intended there.
- tmux comes from the template: the root session is user-owned and escalated
  in-pane with `sudo -i` (not a shared `sudo tmux -S` socket, whose server is
  root-owned); sessions carry `@claude_session` and `@role` pane options;
  `stop`, `cleanup` and the `SessionEnd` hook (`cleanup --idle-only`) reap
  only the calling session's own sessions.
- Every subagent runs on opus, stated in `CLAUDE.md` and in the vendored
  `subagent-driven-development` skill; models are not tiered by difficulty.
- The other machine's GMI guard hook and its `CLAUDE.local.md` stay on that
  machine. `CLAUDE.local.md` is git-ignored here.
- `HARNESS_CHECKLIST.md` is retired; decisions are recorded in this file. Its
  past entries stay in git history.

## 1. File Roles

```text
CLAUDE.md                         always-loaded rule source: code stance, isolation and gates,
                                  conventions (advisory), style
CLAUDE.local.md                   one machine's own rules; loaded with CLAUDE.md, not in the template
.claude/policy/OPERATING_SPEC.md  rationale, design notes, acceptance criteria
.claude/skills/dev-flow/          order of work for a code change, request to merge;
                                  references/ holds a worked sketch and the ADR template
.claude/ENV.md                    environment identity and activation commands
.claude/settings.json             SessionStart/SessionEnd hooks + broad permission grants
.claude/hooks/session_start.sh    state reinjection at session start
.claude/hooks/session_end.sh      safety-net cleanup of this session's idle tmux sessions
.claude/skills/tmux-control/      visible shell/root workflow helper
.claude/skills/superpowers/       vendored Superpowers plugin, locally amended (section 7)
```

Deleted on 2026-08-12: `.claude/hooks/access_guard.sh`,
`.claude/hooks/pre_tool_use_guard.sh`, `.claude/hooks/pre_tool_use_bash_guard.sh`,
`.claude/hooks/post_tool_use_privilege_guard.sh`, `.claude/harness/run.sh`,
`.claude/access.conf`. They had been unregistered since the rollback; the
rationale above is the record, and `verify_setup.sh` asserts their absence.

Folded on 2026-11-13: `.claude/policy/AGENT_RULES.md` into `CLAUDE.md`
(Conventions), wording kept. It was not auto-loaded: only a pointer led to it,
so its rules held only when the agent went and read it. `CLAUDE.md` is always
in context, for subagents too. One line was not carried over, "one minimal
patch before investigation": the vendored `systematic-debugging` skill says the
opposite (no fix before root-cause investigation) and prevails.
`verify_setup.sh` asserts the file's absence.

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
workarounds live in `CLAUDE.md` so environment details do not become a
second policy file.

Conda activation is shell state, so it is not encoded in `.claude/settings.json`
`env`.

## 6. Change Discipline

The harness keeps the useful parts of the original operating spec, now stated
in `CLAUDE.md`:

- no unapproved patches to code outside the repo (Conventions);
- prefer existing modules/helpers over parallel systems (Code stance, rule 5);
- define success criteria and run meaningful validation (Conventions).

"Propose subsystem refactors first" is replaced by the mode gate: the agent
proposes `feat/`, `refactor/` or `fix/` and the user confirms.

The conventions are judgment rules. They should guide behavior without turning
every task into ceremony.

## 7. Skills And Plugins

`tmux-control` and `dev-flow` are standalone project skills because they are
part of this harness.
`superpowers` is copied as a complete project-scope plugin directory because
its repo-level glue files matter. Avoid flattening third-party plugin repos
unless the loss of their root metadata is intentional and documented. The
vendored `dx` plugin was removed on 2026-11-13.

`superpowers` is no longer a pristine copy. Local changes, all in skill text:

- hand-offs return to `dev-flow` (`brainstorming`, `executing-plans`,
  `subagent-driven-development`, `using-superpowers`);
- `finishing-a-development-branch` is deleted; `dev-flow`'s Finalize step
  replaces its four ways of finishing with one;
- `test-driven-development` and `writing-plans` ask for the code the agreed
  contract calls for, not the minimal code that passes the test;
- `test-driven-development` and `systematic-debugging` name the red-test
  verdict rule before a fix;
- `systematic-debugging` states investigation before a fix as a strong
  preference with room for judgement, not as a law;
- the `defense-in-depth` technique is removed from `systematic-debugging`: it
  asks for validation at every layer, and the code stance validates once, at
  the boundary;
- `writing-plans` has a Contract section (Decision, signatures, variation
  axes) and a migration table for refactors, and no checkbox prefix on steps;
- `brainstorming` names what `dev-flow` step 4 asks of a spec;
- "without explicit user consent" is removed from the two lines about
  starting work on `main`;
- `subagent-driven-development` (Model Selection, BLOCKED handling, and its
  implementer and task-reviewer prompts) dispatches every role on opus instead
  of tiering models by difficulty (2026-11-09).

The record of these changes is this repository's git history. An upstream
update means re-applying them. The plugin's README, its Codex reference and one
regression test (`tests/claude-code/test-worktree-path-policy.sh`) no longer
refer to the deleted skill. Upstream's release notes and dated design docs
still name it; they are history and are left as shipped. The plugin's
SessionStart injection is unchanged; it does
not reach subagents, which is one reason rules live in `CLAUDE.md`.

## 8. Portability

`.claude/PORTABLE_SETUP.md` describes bundle/install/chmod/verify steps.
`.claude-workflow/bundle_claude_dirs.sh` should package `CLAUDE.md`, `.claude/`,
and `.claude-workflow/`. Generated runtime state stays out of the portable
bundle unless explicitly requested.

## 9. Acceptance Criteria

Setup is considered correct when all are true:

1. `bash .claude/verify_setup.sh` passes.
2. `CLAUDE.md` states the runtime conventions itself and points to the
   rationale and environment sources.
3. `CLAUDE.md` is the only rule source, and its conventions are
   advisory — no blocking hooks are registered.
4. `OPERATING_SPEC.md` explains design/rationale without becoming a second
   stronger rule layer.
5. `settings.json` registers only the SessionStart hook, allows tools broadly,
   and contains no machine-specific absolute paths.
6. `git push`, `git reset --hard`, and `sudo` remain on the permissions `ask`
   list.
7. Environment details live in `.claude/ENV.md`.
8. A rule is stated once: `CLAUDE.md` for standing rules, `dev-flow` for the
   order of work. Skills name a rule and do not restate it.
9. `CLAUDE.md` is under 200 lines and names no host, machine path or repo.
10. Every concept `CLAUDE.md` or `dev-flow` uses is generally known or is
    established in one of the two.

## 10. Maintenance Procedure

When updating this harness intentionally:

1. Record the decision being made in this file.
2. Keep active scripts Bash-only.
3. Prefer editing the canonical source over repeating a rule in more files.
4. Run `bash .claude/verify_setup.sh`.
5. Review `git diff` before committing.
