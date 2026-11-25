#!/usr/bin/env bash
set -euo pipefail

# Install prov once per machine, at one ref (a release tag), for every workspace (ADR 0011):
# the prov and prov-journal CLIs with `uv tool install`, and the prov-skills Claude Code
# plugin at user scope from the prov marketplace pinned to the same ref. A rerun with the same
# ref ends in the same state; with a new ref, everything moves to it.

if [ "$#" -ne 1 ]; then
  printf 'usage: install_prov.sh <ref>   (a prov release tag; repo: PROV_REPO, default v-sangli/prov)\n' >&2
  exit 2
fi
REF="$1"
REPO="${PROV_REPO:-v-sangli/prov}"
SRC="git+https://github.com/$REPO@$REF"

for cmd in uv claude jq; do
  command -v "$cmd" >/dev/null || { printf 'install_prov: %s is not on PATH\n' "$cmd" >&2; exit 1; }
done

uv tool install --reinstall "prov @ $SRC#subdirectory=packages/prov"
uv tool install --reinstall "prov-journal @ $SRC#subdirectory=packages/prov-journal" \
  --with "prov @ $SRC#subdirectory=packages/prov"

# A marketplace keeps the ref it was added at; moving it to another ref is remove + add,
# and the remove uninstalls its plugin, which the install below puts back.
if ! claude plugin marketplace list --json \
    | jq -e --arg repo "$REPO" --arg ref "$REF" 'any(.[]; .name == "prov" and .repo == $repo and .ref == $ref)' >/dev/null; then
  if claude plugin marketplace list --json | jq -e 'any(.[]; .name == "prov")' >/dev/null; then
    claude plugin marketplace remove prov
  fi
  claude plugin marketplace add "$REPO#$REF"
fi
claude plugin install prov-skills@prov --scope user

prov --help >/dev/null
prov-journal --help >/dev/null
printf 'install_prov: prov, prov-journal and prov-skills@prov at %s (%s)\n' "$REF" "$REPO"
