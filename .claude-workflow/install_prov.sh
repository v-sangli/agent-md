#!/usr/bin/env bash
set -euo pipefail

# Install prov once per machine, for every workspace (ADR 0011): one clone at a ref (a release
# tag) with its own venv, its CLIs linked onto PATH, its skills linked into the user's Claude
# skills, and a pointer file the session-start hook reads. A rerun with the same ref ends in
# the same state; with a new ref, everything moves to it.

if [ "$#" -ne 1 ]; then
  printf 'usage: install_prov.sh <ref>   (a prov release tag)\n' >&2
  printf 'env: PROV_HOME (~/.local/share/prov)  PROV_REPO_URL (https://github.com/v-sangli/prov)\n' >&2
  printf '     PROV_BIN_DIR (~/.local/bin)  CLAUDE_SKILLS_DIR (~/.claude/skills)\n' >&2
  printf '     PROV_POINTER (~/.config/prov/install.toml)\n' >&2
  exit 2
fi
REF="$1"
HOME_DIR="${PROV_HOME:-$HOME/.local/share/prov}"
REPO_URL="${PROV_REPO_URL:-https://github.com/v-sangli/prov}"
BIN_DIR="${PROV_BIN_DIR:-$HOME/.local/bin}"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
POINTER="${PROV_POINTER:-$HOME/.config/prov/install.toml}"

for cmd in git uv; do
  command -v "$cmd" >/dev/null || { printf 'install_prov: %s is not on PATH\n' "$cmd" >&2; exit 1; }
done

# 1. The clone, detached at the ref.
if [ ! -d "$HOME_DIR/.git" ]; then
  git clone --quiet "$REPO_URL" "$HOME_DIR"
fi
git -C "$HOME_DIR" fetch --quiet --tags origin
git -C "$HOME_DIR" checkout --quiet --detach "$REF"
COMMIT="$(git -C "$HOME_DIR" rev-parse HEAD)"

# 2. Its own venv: prov and prov-journal, not editable, so the venv holds the ref's code.
PY="$HOME_DIR/.venv/bin/python"
[ -x "$PY" ] || uv venv --quiet "$HOME_DIR/.venv" --python 3.12
uv pip install --quiet --python "$PY" --reinstall-package prov --reinstall-package prov-journal \
  "$HOME_DIR/packages/prov" "$HOME_DIR/packages/prov-journal"

# 3. Links. A path that exists and is not a link is never replaced.
link() {
  local target="$1" name="$2"
  if [ -e "$name" ] && [ ! -L "$name" ]; then
    printf 'install_prov: %s exists and is not a link; move it away first\n' "$name" >&2
    exit 1
  fi
  ln -sfn "$target" "$name"
}
mkdir -p "$BIN_DIR" "$SKILLS_DIR"
for cli in prov prov-journal; do
  link "$HOME_DIR/.venv/bin/$cli" "$BIN_DIR/$cli"
done
skills=()
for dir in "$HOME_DIR"/packages/prov-skills/skills/*/; do
  name="${dir%/}"; name="${name##*/}"
  link "${dir%/}" "$SKILLS_DIR/$name"
  skills+=("$name")
done

# 4. The pointer file: one `key = "value"` per line, read by .claude/hooks/session_start.sh.
mkdir -p "${POINTER%/*}"
cat >"$POINTER" <<EOF
# Written by install_prov.sh; rerun it to change. Read by the harness's session start.
home = "$HOME_DIR"
ref = "$REF"
commit = "$COMMIT"
python = "$PY"
bin = "$BIN_DIR"
skills = "${skills[*]}"
usage = "$HOME_DIR/docs/usage.md"
EOF

"$BIN_DIR/prov" --help >/dev/null
"$BIN_DIR/prov-journal" --help >/dev/null
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'install_prov: note: %s is not on PATH\n' "$BIN_DIR" >&2 ;;
esac
printf 'install_prov: prov %s (%s) at %s; skills: %s; pointer: %s\n' \
  "$REF" "${COMMIT:0:7}" "$HOME_DIR" "${skills[*]}" "$POINTER"
