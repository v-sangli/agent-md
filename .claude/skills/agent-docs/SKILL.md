---
name: agent-docs
description: Use before working with a tool, host, environment or device of this workspace, and whenever you learn, or the user gives or corrects, a fact about one. Keeps the user-scoped store of workspace facts, ~/.agent-docs/, and its generated index.
---

# Agent Docs

The store of workspace facts: what it takes to work with the user's tools, hosts and
repos. There is one store per user, `~/.agent-docs/`, outside every repo. The user reads
it and adds to it; the agent keeps it current.

## The store

- A doc is any `*.md` under `~/.agent-docs/`, except `INDEX.md` and any path with a
  component starting with `.`. Subdirectories follow concerns, any depth. A doc's path
  is its identity.
- Its first three lines are exactly:

  ```text
  ---
  description: <what this doc covers, on one line, written for recall>
  ---
  ```

  The body is free markdown.
- `INDEX.md` is generated from the descriptions. It is never edited by hand.
- Facts, not rules. A line that tells the agent how to behave belongs in `CLAUDE.md`.
- Real credentials are recorded as pointers: where the secret lives and how to fetch it.
  Low-stakes values may be written inline.

## Look up

`CLAUDE.md` imports the index, so it is in context. Before working with a tool, host,
environment or device, read the doc the index names for it. If the session-start output
reports the store missing or broken, tell the user.

## Write

When you learn a workspace fact, or the user gives or corrects one:

1. Put it in the doc that covers its concern, or create a doc in the right directory,
   frontmatter first.
2. From the workspace root, run `bash .claude/skills/agent-docs/scripts/agent_docs.sh index`.
3. Tell the user in one line: the doc's path and what changed.

Write without asking. Rewriting or removing content already in a doc is proposed first,
with the change shown: it may be something the user wrote.

## Organize

- One concern per doc. A doc that has grown to cover two is split; two docs that overlap
  are merged. Both are rewrites, so both are proposed first.
- Directories follow concerns. A description is specific enough to choose the doc from
  the index alone.

## The script

`agent_docs.sh [--root DIR] index|check`, `--root` defaulting to `~/.agent-docs`.

- `index` validates every doc, then rewrites `INDEX.md`.
- `check` validates every doc and that `INDEX.md` is current.

Both print `agent-docs: OK (<n> docs)`, or exit 1 with `agent-docs: <path>: <reason>` for
the first invalid doc, and `index` then leaves `INDEX.md` unchanged. Fix the doc it names
and run it again.
