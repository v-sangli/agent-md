# Claude Project Context

This repository is a Claude Code workspace/harness under active design. Before changing its
structure, read `.claude/policy/OPERATING_SPEC.md`; record the decision as an ADR under
`docs/adr/` and keep the spec describing the current design.

- `.claude/ENV.md`: environment contract.
- `CLAUDE.local.md`, where present: this machine's own rules. Hosts, machine paths and repo
  names belong there and nowhere in this file.

## Code stance

Scope: code design and development in any repo. Experiments follow their own provenance
rules, which are not set here. These rules bind whoever writes the code, subagents included.

1. **Lean, fail-loud code.** Take full view of the repo's features and cover strictly those.
   The logic stays readable: no handlers, guards, fallbacks, or compatibility, type or
   validity checks woven into it. Callers pass the agreed types; when they don't, the code
   fails immediately and loudly. A handler inside the logic signals an end-to-end flow that
   is not maintained: fix the flow, not the function. Rule 2 says where checks live.
2. **Validate once, at the boundary; full trust inside.** Checks and validation are kept
   apart from the code's behavior. The first entry layer performs all checks.
   - Check code lives with the contract: each contract type carries its own checks, in its
     feature's folder. The entry layer only calls them. There is no central validation
     module.
   - "Once" means once each time data crosses a public boundary. A function that outside
     callers invoke repeatedly is an entry on each call. Re-checking inside, after the data
     is in, is banned.
   - A test runs the entry layer's checks over every config in the repo.
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
     layers included. `getattr(obj, name, default)` is the same probe, under the same ban.
   - Never inject a variant `if`. No monkey patches in merged code.
5. **Prefer existing infrastructure over standalone implementations.** Rewire pathways
   rather than add hotfixes. Extend existing modules and helpers before adding parallel
   systems.
6. **Every deviation is registered with a reason and an exit condition.** A deviation is a
   patch for a bug in code we do not own, a temporary standalone, an old path kept beside
   its replacement, or a fallback kept on purpose. The most dangerous ones are the
   untracked ones.
   - The registry is `DEVIATIONS.md` at the repo root: one row per deviation (id, where,
     why, patch ref, exit condition). Each code site carries a `DEVIATION(<id>)` comment.
   - On a bug in code we do not own, decide: relay it upstream, move on with it
     registered, or treat it as a feature gap in our own infrastructure (rule 3).
   - Patching is for other people's bugs, not for coordinating with ourselves. In our own
     code there is no "patch first, consolidate later": a feature gap or design gap goes
     through rule 3 before code, and nothing is injected into the core.
7. **A frozen core is a settled typed contract, an oracle and CI.** It exists so that
   features and implementations use and reuse one core, instead of monkey patching without
   checking compatibility.
   - What is frozen is what an ADR declares: its typed contract and the behavior its oracle
     pins. Everything else may churn. A contract freezes only once it is settled.
   - The oracle is the set of tests that pin the current behavior of a piece of code:
     golden outputs, parity against a reference, an API snapshot.
   - A frozen core changes only by refactor or by an end-to-end feature addition (full
     integration, rule 3). A refactor passes the oracle with no test edited.
8. **Every repo runs tests, lint and invariant checks in CI.** An ADR rule that can be
   tested becomes a CI test.
9. **Modular, object-driven, structured by subdirectory; rigid at the variation axes.**
   - Modular: similar code stays together, so each feature can be inspected as a whole,
     debugged and edited without tracing the full repo.
   - Object-driven: a concept with state and behavior is a class that owns both. A
     stateless helper may stay a function.
   - A repo is a tree of subdirectories by concern, not a flat collection of files.
   - A variation axis is a dimension along which the repo expects more than one variant.
     Example: a loader that will read more than one file format has file format as an
     axis. Each repo lists its axes in its README or an ADR.
   - At an axis the boundary and interface are fixed and enforced, with room for expansion
     as a seam only: one concrete implementation behind it, and no base class, hierarchy,
     registry, factory or N-way config until a second variant is real. Generalize over
     known axes, stay concrete elsewhere.
10. **A replacement deletes the old path in the same PR.** Keeping the old path is the
    exception, registered as a deviation (rule 6).
11. **Tracked code cites only tracked records.** No code or doc on `main` cites a plan or a
    spec; the ADR is the one record that does. Docs describe the stable layer, contracts
    and decisions; code, tests and `--help` document the wiring.

### When a test is red

A red test is never just made green. Name the verdict first; it sets the route.

| Verdict | Meaning | Route |
|---|---|---|
| Stale test | The test pins behavior that an agreed change replaced. | Fix the test and say why. |
| Bug | The code departs from its contract. | Fix it at its cause. |
| Feature gap | The contract never covered the case. | Rule 3. |
| Design gap | The contract itself is wrong. | Stop. The contract is re-agreed with the user before more code. |

- The expected failure of a test just written for the task at hand needs no verdict.
- A refactor edits no test: a stale test found during one means it is not a refactor.
- A bug in code we do not own is a deviation (rule 6).
- An implementer subagent acts alone only on a bug inside its own task. On any other
  verdict it stops and reports.

## Isolation and gates

Expect several collaborators, people and agents, working on a project at the same time, and
keep development safe and separated. A feature is reviewable as one whole change, with the
total context of the change and its diff.

- Agree which code version the work is on before it starts: an existing branch or a new
  one. `main` is never the working version.
- One feature per branch. Features are not stacked into the same branch.
- Worktrees are the default for feature branches: each branch works in its own worktree,
  isolated from the others, and returns by PR.
- Commit freely on the branch, one commit per logical change. Never commit on `main`.
- `main` changes only by a squash-merged PR with green CI. Never rebase-merge.
- Spec, plan and spike files live only on the feature branch and are deleted before merge.

Five things need the user's word. The agent proposes, the user confirms.

- **The mode**, which is also the branch prefix. It says where the change sits relative to
  an existing design. Work evolves: switching mode mid-work, or handing work between
  `exp/` and another branch, is the agent's judgement. The agent records the switch and
  its reason on the branch, and the new mode's gates apply.
  - `feat/`: new behavior. Where a design already exists, rule 3 picks the shape, and a
    frozen core is touched only by full integration.
  - `refactor/`: behavior stays the same. The oracle passes with no test edited; where
    there is no oracle, one is written first, before any code changes.
  - `fix/`: the design is trusted and the code departs from it. A failing test comes
    first. The fix is surgical: touch only what you must, and don't refactor things that
    aren't broken. Prefer investigating the cause before any fix: a preference with room
    for judgement, not a law. A fix that exposes a design gap stops and changes mode.
- **The interface sketch**, agreed before any plan is written.
- **A spike.** Spikes are reconnaissance: directories under `spikes/` inside the
  implementation branch, which serve as reference for the feature and never merge. Spike
  code does not edit core or module files; it inherits and overrides them. Coding shortcuts
  are allowed there, except `hasattr` and `getattr(obj, name, default)`. A monkey patch in
  a spike is allowed but logged, each one as a missing extension point.
- **An `exp/` branch**, the default home for experiment work. It must be allowed explicitly.
- **A release.** A tag, a GitHub Release, or a prov release label moved. The agent
  proposes it with its checks and its rollback plan, ends its turn, and ships it only on
  the user's word (`shipping-and-launch`). A release pushes tags and the prov registry,
  never `main`.

Any code change in a repo, an allowed `exp/` branch aside, goes through the `dev-flow`
skill: the order of work from request to merge, what each step produces and who confirms it.

## Research work

- Experiment work lives on an `exp/` branch and is recorded with the project's provenance
  tool (`prov`) and its skills (`prov`, `prov-journal`, `prov-plot`). Read the journal's
  `NOW.md` before starting. Session start says whether `prov` is installed on the machine.
- An ID or alias from `prov` (`run_…`, `ds_…`, `doc_…`, `model:<name>/3`) is resolved with
  `prov show`, `trace` or `uses` before anything is assumed about it (the `prov` skill).
- The provenance records are the trace. Every run, dataset and finding is registered
  there and persists whatever becomes of the branch. A finding cites the IDs it rests on.
- When an experiment needs a feature, fix or refactor, that work goes on its own branch
  through `dev-flow`, isolated from the experiment. It may branch from the `exp/` branch
  and return to it by PR.

## Conventions

Conventions and defaults, not gates: no tool call is blocked (see
`.claude/policy/OPERATING_SPEC.md`). Follow them unless there is a concrete reason not to.

- **Workspace boundary.** Write/delete work stays inside the repo unless the user grants
  external scope. Treat `.claude/**` as setup configuration: edit it for harness
  maintenance, not as part of ordinary task work.
- **Shell execution.** Direct Bash is fine for any command, `rm -rf` inside the workspace
  included. Prefer `tmux-control` for tests, installs, builds, benchmarks, nested agents and
  long-running work: a visible, attachable session and a durable log; this is
  encouragement, not a gate. Invoke helper scripts by absolute path or from the workspace
  root: the shell cwd drifts between calls. Never poll with a foreground `sleep`; wait with `tmux_control.sh
  wait` or `Monitor`. Stop every tmux session you started when its work is done
  (`stop`/`cleanup`), never one you did not.
- **Privilege.** For sudo/root, offer the `tmux-control` root session first
  (`tmux_control.sh root-request`): the opaque shell cannot surface password prompts. It is
  a user-owned session escalated in-pane with `sudo -i`, never `sudo tmux` (a root-owned
  server the agent cannot reach). Send nothing before `^root@`; `stop` it when done.
- **Subagent models.** Dispatch every subagent with `model: opus`. Do not tier models by
  task difficulty: better first implementations mean less debugging.
- **Environment.** Read `.claude/ENV.md` before Python, pytest, uv, dependency, install,
  or build work, and use the default environment it names unless the user overrides it.
  Do not use `PYTHONPATH=.` as a durable fix.
- **Code outside the repo.** Do not patch `site-packages`, system paths, external
  dependency checkouts, or other outside-repo code without explicit approval. Prefer
  in-repo fixes, dependency pins/upgrades, wrappers, or vendored patches.
- **Editing.** `Read` a file before `Write`/`Edit`; the tools reject an unread target.
- **Verification.** Define success criteria before substantial edits. Run the smallest
  meaningful validation after edits, and loop until verified. For harness changes,
  `bash .claude/verify_setup.sh` is the baseline verifier.

## Shell command shape

These apply to subagents and Monitor/watcher commands too.
- Never use `$(...)` or backticks. Command substitution cannot be checked statically, so
  it always raises an approval prompt that no allowlist can suppress — that prompt has no
  "don't ask again" option. Rewrite without it.
- To wait on a process: `while pgrep -f "[p]attern" >/dev/null; do sleep 5; done`. Test the
  exit status directly; no `$(pgrep ...)` + `kill -0` needed. The bracket around the first
  character keeps `pgrep -f` from matching the waiting loop's own command line — without it
  the loop matches itself and never exits.

## Karpathy guidelines

**Think before coding.** Don't assume. Don't hide confusion. Surface tradeoffs.
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

**Scope of a change.**
- No features beyond what was asked. Nothing speculative.
- If you write 200 lines and it could be 50, rewrite it.
- Don't improve adjacent code, comments, or formatting unless directly required.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.
- Remove imports, variables, and functions that your changes made unused.
- Every changed line should trace directly to the user's request.
