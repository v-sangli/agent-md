# Context Discipline (prevention levers)

Measured in CONTEXT_FORENSICS.md §9. Apply during read/implementation-heavy work.

1. **Subagent offloading** — dispatch an `Explore`/`general-purpose` agent to read N
   files and return conclusions; the file bodies die with its context and never
   enter the main window. Strongest lever for read-heavy phases.
2. **Grep-filter command output** — full `verify_setup.sh` ≈ 2k tokens; piped to
   `grep -E 'FAIL|SUMMARY'` ≈ 50. Filter before it lands in context.
3. **Edit over Write** — 20 `Edit`s on a file ≈ 42 KB of fragments; 20 full
   `Write`s ≈ 280 KB. Prefer `Edit` for iterative changes.

**Externalize to make CoT mortal:** think → write the decision to
HARNESS_CHECKLIST / memory → the reasoning capsule becomes safe to drop
(ctxprune / steered /compact). Un-externalized reasoning is load-bearing and
must NOT be pruned.
