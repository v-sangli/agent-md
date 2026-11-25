# The harness installs prov once per machine

Mode: `feat/` extend. Branch: `feat/prov-integration`.

## Problem

CLAUDE.md sends research work to `prov` "and the skills it installs", but the harness neither
installs prov nor says how its skills reach a session. A machine runs several workspaces; a
copy of prov per workspace (a submodule) would let them drift onto different versions while
they share one registry, store and config.

## Contract

- `.claude-workflow/install_prov.sh <ref>` installs, at one prov ref (a release tag):
  the `prov` and `prov-journal` CLIs with `uv tool install`, and the `prov-skills` plugin at
  user scope from the `prov` marketplace pinned to that ref. Run again with the same ref it
  ends in the same state; with a new ref it moves everything to it. No argument: usage, exit 2.
- `PORTABLE_SETUP.md` gains the step. CLAUDE.md's Research work names the plugin and says an
  ID or alias is resolved with prov, not guessed.
- No submodule, no copy of prov in the harness.

## Variation axes

None new. The prov repo is a variable (`PROV_REPO`, default the upstream repo).

## Intake shape

Full integration: a setup script beside the existing workflow scripts.

## Sketch (agreed 2026-11-24)

```
.claude-workflow/install_prov.sh <ref>   uv tool install prov, prov-journal @ <ref>;
                                         marketplace prov @ <ref> (remove + add if at another ref);
                                         claude plugin install prov-skills@prov --scope user
.claude/PORTABLE_SETUP.md                new step: prov, once per machine
CLAUDE.md                                Research work: the prov-skills plugin; resolve IDs with prov
.claude/verify_setup.sh                  the script exists, is executable, prints usage without args
docs/adr/0011-prov-is-installed-once-per-machine.md
OPERATING_SPEC.md                        file roles; Version 3.6
```
