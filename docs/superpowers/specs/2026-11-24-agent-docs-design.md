# Agent docs: a user-scoped store of workspace facts

Date: 2026-11-24
Branch: `feat/agent-docs` (mode `feat/` extend)

## Problem

The context needed to work with our tools and repos (how to reach a compute cluster and
run training there, which Python environment a repo uses, how a robot starts up) has one
home today: `.claude/ENV.md`. It holds a single topic, is tracked in a template that is
meant to name no machine, and needs a carve-out in the verifier for that. Claude Code's
built-in auto memory is not the answer: it is opaque and not ours to configure.

We want a store of named markdown files, organized by concern, that the agent keeps up
to date by default and that the user can read and append to.

## Contract

The harness promises:

- every session and every subagent has the store's index in context;
- the agent reads the doc that covers a tool, host or environment before working with it;
- the agent records a workspace fact it learns, without asking, and says so in one line;
  it proposes before rewriting or removing content already in a doc;
- a store that is missing or malformed is reported at session start, never silently
  ignored.

Inputs: docs written by the agent or the user under `~/.agent-docs/`. Output: a
generated `INDEX.md`, imported by `CLAUDE.md`.

## The store

- **Root:** `~/.agent-docs/`. User-scoped, untracked, never bundled. One store per user;
  no workspace scope.
- **Docs:** any `*.md` under the root except `INDEX.md`, in a tree of subdirectories by
  concern, any depth. A doc's path relative to the root is its identity.
- **Frontmatter:** closed, exactly one key, a non-empty single line:

  ```markdown
  ---
  description: <what this doc covers, written for recall>
  ---
  ```

  The body is free markdown.
- **`INDEX.md`:** at the root, generated, never edited by hand. A header names the root
  and says the file is generated; then one heading per directory, one line per doc:

  ```markdown
  ## compute
  - `compute/<doc>.md`: <description>
  ```

  Docs at the root are listed before the first heading.
- **Content:** facts, not rules. A line that tells the agent how to behave belongs in
  `CLAUDE.md`. Real credentials are recorded as pointers (where the secret lives and how
  to fetch it); low-stakes values may be written inline. Nothing enforces this.

## The `agent-docs` skill

A standalone project skill, beside `tmux-control`; not part of `dev-flow`.

```text
.claude/skills/agent-docs/
  SKILL.md                 the procedure
  scripts/agent_docs.sh    index | check  (Bash, like the other harness scripts)
  tests/fixtures/          stores the verifier runs the script against
```

`SKILL.md` fires on reading or writing workspace facts and states:

- **Look up:** the index is in context; read the doc it names before working with that
  tool, host or environment.
- **Write:** a new fact goes into the doc that covers it, or a new doc in the right
  directory; then run `index`; then report the change in one line. Rewriting or removing
  existing content is proposed first.
- **Organize:** one concern per doc; split a doc that has grown to two, merge two that
  overlap; directories follow concerns.
- **Out of scope:** behavior rules (`CLAUDE.md`); real credentials go in as pointers.

`agent_docs.sh [--root DIR] <command>`, `--root` defaulting to `~/.agent-docs`:

- `index`: validates every doc, then rewrites `INDEX.md`. On the first invalid doc it
  exits non-zero with the path and the reason, and leaves `INDEX.md` unchanged.
- `check`: validates every doc and compares `INDEX.md` with what `index` would write.
  Exits non-zero on a missing root, missing frontmatter, a missing or unknown key, an
  empty or multi-line `description`, or a stale or missing index. On success it prints
  `agent-docs: OK (<n> docs)`.

The script is the boundary: validation lives there and only there. There is no `init`;
the first doc write creates the root and `index` creates `INDEX.md`.

## Harness integration

- **`CLAUDE.md`:**
  - the `.claude/ENV.md` pointer is replaced by `@~/.agent-docs/INDEX.md` and a one-line
    role for it;
  - Conventions › Environment: before Python, pytest, uv, dependency, install or build
    work, read the agent doc that covers the environment and use the default it names.
    The `PYTHONPATH=.` line stays;
  - Conventions › Workspace boundary: `~/.agent-docs/` may be written without asking.
- **`.claude/settings.json`:** `permissions.additionalDirectories: ["~/.agent-docs"]`.
  `Read`, `Edit` and `Write` are already allowed tool-wide.
- **`.claude/hooks/session_start.sh`:** the ENV.md line is replaced by the output of
  `agent_docs.sh check`. Advisory: it reports and blocks nothing.
- **ENV.md is removed in this PR (rule 10):** `.claude/ENV.md` is deleted; the verifier
  drops its file and content checks and its carve-out in the portability check, which
  then tolerates absolute home paths only in `settings.local.json`;
  `.claude/PORTABLE_SETUP.md` and `.claude-workflow/README.md` follow.
- **This machine:** ENV.md's content becomes `~/.agent-docs/envs/python.md` before the
  branch's `CLAUDE.md` changes.
- **Records:** ADR 0011 (the store and its contract; supersedes the ENV.md design);
  `OPERATING_SPEC.md` §1 file roles, §5 rewritten as "Workspace facts", §7 skills, §9
  criterion 7; a minor version bump.

## Spike findings the design rests on

`spikes/agent-docs-location/README.md`, Claude Code 2.1.332, default permission mode:

- an agent edit under `~/.claude/` prompts even with explicit allow rules; the same
  rules on another home directory silence both read and edit prompts. Hence the root is
  outside `~/.claude`;
- an `@~/...` import in a project `CLAUDE.md` loads after a one-time per-workspace
  dialog; declining disables it silently;
- imported content reaches a `general-purpose` subagent;
- a missing import target is silent. Hence the session-start check.

## Testing

In `.claude/verify_setup.sh`, run by CI on every PR (ADR 0008).

The script against fixtures:

| Fixture | Expect |
|---|---|
| `good/`: nested dirs, valid docs, golden `INDEX.md` | `check` passes; `index` on a temp copy reproduces the golden file byte for byte |
| `no-frontmatter/` | `check` fails, naming the doc |
| `extra-key/` | fails: unknown key |
| `empty-description/`, `multiline-description/` | fails |
| `stale-index/` | fails: index stale |
| a root that does not exist | fails: missing root |
| `index` over an invalid doc | non-zero exit, `INDEX.md` unchanged |

The wiring: `CLAUDE.md` carries the import line; `settings.json` lists `~/.agent-docs`
in `additionalDirectories`; `.claude/ENV.md` is absent and no tracked file names it,
outside `docs/adr/` (history) and the branch-only `docs/superpowers/` and `spikes/`; the session hook's output has an `agent-docs:` line.

Not visible to CI: the live store. Before the PR, one manual end-to-end run on this
machine (a nested session in a workspace on the branch) confirms that the index loads
and reaches a subagent, and that `additionalDirectories` alone silences the write
prompt.

## Variation axes and intake

- **Variation axes:** none new. The store location and the doc format are fixed: one
  store, one format, no backends.
- **Intake shape:** full integration. The store takes over ENV.md's role as if it had
  always belonged to the harness; the old path goes in the same PR.

## Agreed interface sketch (2026-11-24)

### The data that crosses

**A doc**: any `*.md` under the root, except `INDEX.md` and any path with a component
starting with `.`. Its first three lines are exactly:

```text
---
description: <non-empty text on this one line>
---
```

That is the whole frontmatter grammar: another key, a second key or a wrapped description
is a mismatch on line 2 or 3. The body follows, free markdown.

**`INDEX.md`**, generated:

```markdown
# Agent docs

Generated by `agent_docs.sh index` from each doc's frontmatter. Do not edit.
Paths are relative to the store root.

- `<root-doc>.md`: <description>

## compute
- `compute/<doc>.md`: <description>

## compute/clusters
- `compute/clusters/<doc>.md`: <description>
```

Root docs first, then one heading per directory, by its full relative path (not nested).
Docs and directories sorted with `LC_ALL=C`. A directory appears only if it holds docs.

### The script: `scripts/agent_docs.sh`

```text
agent_docs.sh [--root DIR] index    # validate all docs, then write INDEX.md
agent_docs.sh [--root DIR] check    # validate all docs, compare INDEX.md with what index would write
```

| Exit | Meaning | Output |
|---|---|---|
| 0 | store valid (`check`) / index written (`index`) | stdout: `agent-docs: OK (<n> docs)` |
| 1 | invalid store | stderr: `agent-docs: <rel-path or root>: <reason>`, first failure only |
| 2 | usage error | stderr: usage |

Reasons: `missing root`, `no frontmatter`, `unknown or extra frontmatter key`,
`empty description`, `description not on one line`, `index missing`, `index stale`.

```text
list_docs ROOT            -> sorted rel paths, one per line
validate_doc ROOT REL     -> exit 1 + reason on stderr; called once per doc, the only validation
description_of ROOT REL   -> the description text (trusts validate_doc ran)
render_index ROOT         -> INDEX.md content on stdout (trusts validation)
cmd_index ROOT            -> validate all, then write render_index to INDEX.md
cmd_check ROOT            -> validate all, then diff render_index against INDEX.md
```

`cmd_index` writes `INDEX.md` only after every doc is valid.

### Directory layout

```text
.claude/skills/agent-docs/
  SKILL.md
  scripts/agent_docs.sh
  tests/fixtures/
    good/                  root doc, nested dirs, golden INDEX.md
    no-frontmatter/
    extra-key/
    empty-description/
    multiline-description/
    stale-index/
```

"Missing root" runs against a nonexistent path; "`index` over an invalid doc" against a
temp copy of `extra-key/`.

### The wiring text

`CLAUDE.md`, replacing the ENV.md pointer:

```markdown
- `~/.agent-docs/`: workspace facts (clusters, environments, devices), kept by the
  `agent-docs` skill. Its index:

@~/.agent-docs/INDEX.md
```

Conventions › Environment: "Before Python, pytest, uv, dependency, install or build work,
read the agent doc that covers the environment and use the default it names. Do not use
`PYTHONPATH=.` as a durable fix."

Conventions › Workspace boundary gains: "`~/.agent-docs/` is in scope: write it without
asking (`agent-docs` skill)."

Session hook: prints the output of `agent_docs.sh check`, or its failure line; the hook
always exits 0.

`verify_setup.sh` gains `check_agent_docs` (the fixture table) and the wiring asserts, and
loses the ENV.md checks and carve-out.
