---
name: context-handoff
description: Use when the context window is filling, the context-gauge Stop-hook printed a "CONTEXT GAUGE" nudge, /context Messages is high, or a long session needs compacting without losing decisions. The judgment half of semantic compaction — choosing what survives, writing the recap, triggering the clone. Mechanical measurement/prune is done by scripts; this is the model's part.
---

# Context Handoff

## Overview

Semantic compaction = **keep the decisions, drop the reasoning.** The scripts measure and prune mechanically; this skill is the judgment they can't do — pick the cut point, curate the recap, trigger the commit.

Grounding: `CONTEXT_FORENSICS.md` (measured mechanics — CoT is ~67% of window, re-sent every request at full cost; JSONL is a write-through log read only at resume).

## When to Use

- Stop-hook printed the `⚠ CONTEXT GAUGE` nudge.
- `/context` Messages high (>~55% of window).
- Long session; want a lean restart that keeps recent work verbatim.

Not for: fresh sessions, trivial context.

## Procedure

1. **Gauge.** Read the numbers before deciding:
   - `.claude/context/ctxgauge.sh tokens <transcript>` — total + fraction
   - `.claude/context/ctxgauge.sh evictable <transcript>` — reclaimable bytes
   - `.claude/context/ctxgauge.sh perfile <transcript>` — superseded file payloads (drop candidates)
   - `.claude/context/ctxgauge.sh capsules-by-phase <transcript>` — CoT mass per phase

2. **Externalize FIRST.** Any decision that lives only in reasoning → write it to `HARNESS_CHECKLIST.md` / memory NOW. Un-externalized CoT is load-bearing; dropping it loses the "why." One-way: think → externalize → capsule becomes safe to drop. (See `.claude/policy/CONTEXT_DISCIPLINE.md`.)

3. **Write the recap** to `.claude/context/state/recap.md`:
   - **PRESERVE:** decisions, current file states, open TODOs, last verify status.
   - **DROP:** reasoning narratives, superseded file versions, dead ends.
   - Summarize OLD phases; keep recent facts verbatim.

4. **Commit** — pick one actuator:
   - **Steered compact:** `/compact <focus string built from the gauge>` — in-place, model-written summary.
   - **Clone + resume:** `.claude/context/ctxprune.sh clone <session-id>` then `claude --resume <new-id>` — mechanical prune, preserves structure, original archived.
   - **`/rewind → Summarize up to here`** at a clean checkpoint — keeps recent verbatim.

5. **Auto-resume** (if running under `claude-loop.sh`): drop `.claude/context/state/handoff.pending`, then `/exit`. Supervisor relaunches; `SessionStart` injects `recap.md` one-shot.

## Half-Clone Variant (best fidelity)

Summary of OLD phases (from the gauge) + recent segment **verbatim** — including recent thinking signatures, which carry model reasoning continuity even though their text is opaque. Cut on a **clean turn boundary**: a `tool_use` and its `tool_result` must stay together, or `--resume` fails pairing validation.

## Common Mistakes

- Dropping CoT before externalizing → lose the "why." Externalize first.
- Cutting mid tool-use/tool-result group → `--resume` pairing error.
- Summarizing RECENT turns → lose working context. Summarize OLD, keep recent.

Refs: `CONTEXT_FORENSICS.md` (mechanics), `.claude/policy/CONTEXT_DISCIPLINE.md` (prevention), `CONTEXT_ENGINE_PLAN.md` (build).
