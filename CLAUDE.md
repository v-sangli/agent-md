# Claude Project Context

This repository is a Claude Code workspace/harness under active design. Before changing structure, check `HARNESS_CHECKLIST.md` and update it with the decision being made.

Sources:
- `.claude/policy/OPERATING_SPEC.md`: design rationale and acceptance criteria. Read it before changing the harness shape.
- `.claude/ENV.md`: environment contract.

## Code stance

Scope: code design and development in any repo of this workspace. Experiments follow their
own provenance rules, which are not set here.

1. **Defensive code.** Take full view of the repo's features and cover strictly those.
   Code is straightforward: no elaborate compatibility checks, type checks or validity
   checks, no fluff. Any erroneous behavior fails immediately and loudly; a tightly coupled
   infrastructure does not need more. "Defensive" here never means guards and fallbacks:
   those are the fluff this rule removes.
2. **Validate once, at the boundary; full trust inside.** Checks and validation are kept
   apart from the code's behavior. The first entry layer performs all checks.
   - Check code lives with the contract: each contract type carries its own checks, in its
     feature's folder. The entry layer only calls them. There is no central validation
     module.
   - "Once" means once each time data crosses a public boundary. A function that outside
     callers invoke repeatedly is an entry on each call. Re-checking inside, after the data
     is in, is banned.
   - A test runs the entry phase over every config in the repo.
3. **A feature gap is covered by a top-down edit, never patched in place.** Ask explicitly
   what the feature is and how the repo should support it. The edit may be minimal or
   major; that is up to discussion, case by case. It takes one of three shapes:
   - a subclass override, so the core is unchanged and unaffected;
   - a separate temporary standalone, for a single-use patch or feature, registered as a
     deviation (rule 6);
   - full integration, as if the feature had belonged in the repo the whole time.
4. **Contracts are typed and closed: no attributes added ad hoc.** The rule is the
   property, not the construct. In Python the default tool is a frozen dataclass, because
   it stays interpretable and traceable.
   - `hasattr` is banned everywhere in our own code, spikes and third-party-facing entry
     layers included. `getattr(obj, name, default)` is the same probe and falls under the
     same ban.
   - Never inject a variant `if`.
   - No monkey patches in merged code.
5. **Prefer existing infrastructure over standalone implementations.** Rewire pathways
   rather than add hotfixes. Extend existing modules and helpers before adding parallel
   systems.
6. **Every deviation is registered with a reason and an exit condition.** A deviation is a
   patch, a temporary standalone, a path kept beside its replacement, or a fallback. The
   most dangerous ones are the untracked ones.
   - When one is found, decide: relay it upstream, move on with it registered, or treat it
     as a feature gap in our own infrastructure (rule 3).
   - A `PATCH(id)` registry is for other people's bugs, not for coordinating with
     ourselves.
   - In our own code there is no "patch first, consolidate later". A feature gap or design
     gap goes through rule 3 before code; nothing is injected into the core.
7. **A frozen core is a settled typed contract, a refactor oracle and CI.** It exists so
   that features and implementations use and reuse one core, instead of monkey patching
   without checking compatibility.
   - What is frozen is what an ADR declares: its typed contract and the behavior its oracle
     tests pin. Everything else may churn. A contract freezes only once it is settled.
   - A frozen core resists change except by refactor or by an end-to-end feature addition.
     A refactor passes the oracle with no test edited.
8. **Every repo runs tests, lint and invariant checks in CI.** An ADR rule that can be
   tested becomes a CI test.
9. **Modular, spatially separated design everywhere; rigid at the variation axes.**
   - Modular: similar code stays together, so each feature can be inspected as a whole,
     debugged and edited without tracing the full repo.
   - At a variation axis the boundary and interface are fixed and enforced, with room for
     expansion as a seam only: one concrete implementation behind it, and no registry,
     factory or N-way config until a second case is real.
10. **A replacement deletes the old path in the same PR.** Keeping the old path is the
    exception, registered as a deviation (rule 6).

### When a test is red

A red test is never just made green. Name the verdict first; it sets the route.

| Verdict | Meaning | Route |
|---|---|---|
| Stale test | The test pins behavior that an agreed change replaced. | Fix the test and say why. |
| Bug | The code departs from its contract. | Fix at the root cause. |
| Feature gap | The contract never covered the case. | Rule 3. |
| Design gap | The contract itself is wrong. | Stop. The contract is re-agreed with the user before more code. |

- The expected failure of a test just written for the task at hand needs no verdict.
- A refactor edits no test, so a stale test found during a refactor means the work is not
  a refactor.
- Someone else's bug is a deviation (rule 6).
- An implementer subagent acts alone only on a bug inside its own task. On any other
  verdict it stops and reports.

### Records in code

- Tracked code cites only tracked records. No code or doc on `main` cites a plan or a
  spec; the ADR is the one record that does.
- Docs describe the stable layer: contracts and decisions. Code, tests and `--help`
  document the wiring.

## Isolation and gates

Expect several collaborators, people and agents, working on a project at the same time, and
keep development safe and separated. A feature is reviewable as one whole change, with the
total context of the change and its diff.

- Agree which code version the work is on before it starts: an existing branch or a new
  one. `main` is never the working version.
- One feature per branch. Features are not stacked into the same branch.
- Worktrees are the default for feature branches: the root checkout stays on `main`, the
  work happens in a worktree off it and returns by PR.
- `worktree.bgIsolation: "none"` is set in user-scope `~/.claude/settings.json`, so background jobs write to real checkouts directly. That is deliberate. It must live at user scope because the guard is per-git-repo: this workspace root is not a repo, and each subdirectory (`omniteleop`, `dexdata`, `dexstream`, `Isaac-GR00T`, ...) is its own repo whose `.claude/settings.json` the agent cannot write once the guard is active.
- Commit freely on the branch, one commit per logical change. Never commit on `main`.
- `main` changes only by a squash-merged PR with green CI. Never rebase-merge.
- Spec, plan and spike files live only on the feature branch and are deleted before merge.
- Downstream repos pin by version.

These need the user's word. The agent proposes, the user confirms.

- **The mode**, which is the branch prefix. Switching mode mid-work is explicit.
  - `feat/`: new behavior. Extending existing code goes through code stance rule 3.
  - `refactor/`: behavior unchanged. The oracle passes with no test edited.
  - `fix/`: surgical. A failing test comes first. Touch only what you must, and don't
    refactor things that aren't broken.
- **A spike.** Spikes are reconnaissance: directories inside the implementation branch
  that serve as reference for the feature and never merge. Spike code does not edit core
  or module files; it inherits and overrides them. Coding shortcuts are allowed there,
  except `hasattr` and `getattr(obj, name, default)`. A monkey patch in a spike is allowed
  but logged, each one as a missing extension point.
- **An `exp/` branch**, the default home for experiment work. It must be explicitly
  allowed by the user.

## Conventions

As of 2026-07-26 the blocking hook enforcement is rolled back (see
`HARNESS_CHECKLIST.md`): these are conventions and defaults, not gates. Follow
them unless there is a concrete reason not to.

1. Workspace boundary.
- Write/delete work stays inside the repo unless the user grants external scope.
- Treat `.claude/**` as setup configuration: edit it for harness maintenance,
  not as part of ordinary task work.

2. Shell execution.
- Direct Bash is fine for any command, including writes, deletes, and `rm -rf`
  inside the workspace.
- Prefer `tmux-control` for tests, installs, builds, benchmarks, nested agents,
  and long-running work: the user gets a visible, attachable session and a
  durable log. This is encouragement, not a gate.
- Invoke helper scripts with absolute paths, or `cd` to the workspace root
  first — the persistent shell cwd drifts between Bash calls.
- Do not poll with a foreground `sleep`; the harness blocks it. Wait on a
  condition with `tmux_control.sh wait` or the `Monitor` tool.

3. Privilege.
- Prefer the `tmux-control` root-request flow for sudo work: Claude Code's
  opaque shell cannot surface password prompts. Default to a shared root tmux
  session: the user opens it with sudo on its own socket and grants this user
  access (`server-access -a`), the agent drives it via `TMUX_CONTROL_SOCKET`
  while the user watches, and closes it when the scoped task is done.
- Plain `sudo` prompts through permissions; acceptable when the user is
  present and the command is short.

4. Environment.
- Read `.claude/ENV.md` before Python, pytest, uv, dependency, install, or build work.
- Use the default environment named in `.claude/ENV.md` unless the user overrides it.
- Do not use `PYTHONPATH=.` as a durable fix.

5. Code outside the repo.
- Do not patch `site-packages`, system paths, external dependency checkouts, or other outside-repo code without explicit approval.
- Prefer in-repo fixes, dependency pins/upgrades, wrappers, or vendored patches.

6. Editing.
- `Read` a file before `Write`/`Edit`. The tools reject an unread target, so
  guessing at contents costs a round-trip and buys nothing.

7. Verification.
- Define success criteria before substantial edits.
- Run the smallest meaningful validation after edits. Loop until verified.
- For harness changes, `bash .claude/verify_setup.sh` is the baseline verifier.

## Shell command shape

Applies to subagents and Monitor/watcher commands too.

- Never use `$(...)` or backticks. Command substitution cannot be checked statically, so
  it always raises an approval prompt that no allowlist can suppress — that prompt has no
  "don't ask again" option. Rewrite without it.
- To wait on a process: `while pgrep -f "[p]attern" >/dev/null; do sleep 5; done`. Test the
  exit status directly; no `$(pgrep ...)` + `kill -0` needed. The bracket around the first
  character keeps `pgrep -f` from matching the waiting loop's own command line — without it
  the loop matches itself and never exits.
- Keep paths inside the workspace or the session scratchpad. Anything else leaves the sandbox and prompts.

## Karpathy guidelines

Behavioral guidelines to reduce common LLM coding mistakes.

### Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Scope of a change

- No features beyond what was asked. Nothing speculative.
- If you write 200 lines and it could be 50, rewrite it.
- Don't improve adjacent code, comments, or formatting unless directly required.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.
- Remove imports, variables, and functions that your changes made unused.
- Every changed line should trace directly to the user's request.
