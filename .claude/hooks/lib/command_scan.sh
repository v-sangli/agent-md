# Shared command-classification library for the Claude harness guards.
#
# Sourced by access_guard.sh, pre_tool_use_bash_guard.sh, and harness/run.sh so
# they share ONE tokenizer and ONE notion of "what command is this segment
# actually running". Classification is by the *command head* of each pipeline
# segment, never by substring matches on the whole command string -- so an
# interpreter name appearing as an argument (`which bun`, `ls | grep npm`) is
# read-only, not a mutating command.
#
# Provides:
#   is_separator <token>            -> 0 if token is a shell command separator
#   tokenize_command <string>       -> prints one shell token per line
#   cs_transparency_class <string>  -> prints: sudo | interpreter | plain
#   cs_decide <string>              -> prints: sudo | interpreter | native |
#                                              clean | opaque
#
# cs_decide semantics (for the single-decider Bash guard):
#   sudo        -> route to the visible root-terminal flow
#   interpreter -> route to tmux (tests / installs / builds / agents)
#   native      -> force fall-through to Claude Code's native permission rules
#                  (git push / git reset keep their native ask rules)
#   clean       -> every segment head is statically known (read-only tools,
#                  mutators whose targets the access classifier scans, or
#                  sanctioned harness entrypoints); safe to auto-allow when the
#                  access classifier agrees about write targets
#   opaque      -> something is not statically classifiable (unknown heads,
#                  command substitution, eval, ...); leave the decision to the
#                  native permission engine
#
# This file is meant to be *sourced*; it defines functions only.

[ -n "${_CS_LIB_LOADED:-}" ] && return 0
_CS_LIB_LOADED=1

is_separator() {
  case "$1" in
    ';'|'&&'|'||'|'|'|'&'|'('|')') return 0 ;;
    *) return 1 ;;
  esac
}

tokenize_command() {
  local input="$1" len i ch next token quote escape
  len="${#input}"
  token=""
  quote=""
  escape=0

  for ((i = 0; i < len; i++)); do
    ch="${input:i:1}"
    if [ "$escape" -eq 1 ]; then
      token+="$ch"
      escape=0
      continue
    fi

    if [ -n "$quote" ]; then
      if [ "$ch" = "\\" ] && [ "$quote" = '"' ]; then
        escape=1
      elif [ "$ch" = "$quote" ]; then
        quote=""
      else
        token+="$ch"
      fi
      continue
    fi

    case "$ch" in
      "'"|'"') quote="$ch" ;;
      "\\") escape=1 ;;
      $'\n')
        # Newline separates commands exactly like `;` -- without this, the
        # second line of a multi-line command would be scanned as ARGUMENTS
        # of the first line's head (a fail-open).
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        printf ';\n'
        ;;
      $' '|$'\t'|$'\r')
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        ;;
      ';'|'('|')')
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        printf '%s\n' "$ch"
        ;;
      '&')
        next="${input:i+1:1}"
        if [ "$next" = "&" ]; then
          if [ -n "$token" ]; then
            printf '%s\n' "$token"
            token=""
          fi
          printf '&&\n'
          i=$((i + 1))
        elif [ "$next" = ">" ]; then
          if [ -n "$token" ]; then
            printf '%s\n' "$token"
            token=""
          fi
          printf '&>\n'
          i=$((i + 1))
        else
          # Lone `&` backgrounds the command: a separator, like `;` -- else
          # `ls & rm ...` would scan rm as an argument of ls (a fail-open).
          if [ -n "$token" ]; then
            printf '%s\n' "$token"
            token=""
          fi
          printf '&\n'
        fi
        ;;
      '|')
        next="${input:i+1:1}"
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        if [ "$next" = "|" ]; then
          printf '||\n'
          i=$((i + 1))
        else
          printf '|\n'
        fi
        ;;
      '>')
        next="${input:i+1:1}"
        if [ -n "$token" ]; then
          printf '%s\n' "$token"
          token=""
        fi
        if [ "$next" = ">" ]; then
          printf '>>\n'
          i=$((i + 1))
        elif [ "$next" = "&" ]; then
          # `2>&1` fd-duplication: emit one `>&` token so the digit that
          # follows is consumed as its operand, not as a command head.
          printf '>&\n'
          i=$((i + 1))
        else
          printf '>\n'
        fi
        ;;
      '#')
        if [ -z "$token" ]; then
          # Word-initial unquoted `#` starts a comment: consume to end of
          # line so commented-out text is neither classified nor blocked.
          while [ $((i + 1)) -lt "$len" ] && [ "${input:$((i + 1)):1}" != $'\n' ]; do
            i=$((i + 1))
          done
        else
          token+="$ch"
        fi
        ;;
      *) token+="$ch" ;;
    esac
  done

  if [ -n "$token" ]; then
    printf '%s\n' "$token"
  fi
}

# --- classification ----------------------------------------------------------
#
# Globals set by a scan:
#   _CS_CLASS        plain < interpreter < sudo (highest seen wins)
#   _CS_CLEAN        1 while every segment head is statically known
#   _CS_FORCE_NATIVE 1 if a segment must be left to native permission rules

# Interpreter / test / install / build / agent tools whose runs should be
# visible and persistent (routed to tmux).
_CS_INTERPRETERS=" python python2 python3 pytest uv pip pip2 pip3 pipx npm npx \
pnpm yarn bun deno node cargo rustc make cmake ninja meson go gcc g++ cc clang \
clang++ ruby gem bundle bundler rake rails java javac gradle mvn tox nox conda \
mamba poetry virtualenv ipython jupyter maturin claude codex "

# Heads whose effects are fully visible to the access classifier: read-only
# inspectors, plus mutators whose file targets access_guard scans, plus shell
# state changes with no filesystem effect. NOTE: awk/sed are here for parity
# with the native settings.json allowlist (`Bash(awk:*)`, `Bash(sed:*)`).
_CS_SAFE_HEADS=" pwd ls find rg grep egrep fgrep cat head tail wc nl sort uniq \
stat file du df which whereis realpath readlink basename dirname tree less \
more strings od xxd jq diff cmp comm column tr cut paste date hostname uname \
id whoami env printf echo test [ true false : md5sum sha1sum sha256sum awk sed \
rm rmdir mkdir touch truncate chmod chown install tee cp mv \
cd export unset set shopt done fi esac } seq sleep break continue "

# Read-only git subcommands (safe to auto-allow).
_CS_GIT_RO=" status diff log show rev-parse ls-files ls-tree cat-file blame \
describe grep shortlog reflog branch remote "

# Mutators from _CS_SAFE_HEADS whose safety depends on access_guard scanning
# their literal targets. When one is reached through a variable head the
# target scan is blind, so a resolved-alias mutator is never clean.
_CS_MUTATOR_HEADS=" rm rmdir mkdir touch truncate chmod chown install tee cp \
mv sed "

# Leading VAR=value assignments seen earlier in the same command, used to
# resolve alias heads: TC=/path/tool.sh ... "$TC" send ...
declare -gA _CS_ASSIGN=()

_cs_promote() {
  case "$1" in
    sudo) _CS_CLASS="sudo" ;;
    interpreter) [ "$_CS_CLASS" = "sudo" ] || _CS_CLASS="interpreter" ;;
  esac
}

# Is a bare command name an interpreter-class tool?
_cs_class_head() {
  local h="${1##*/}"
  case "$h" in
    bugsinpy-*) _cs_promote interpreter; return 0 ;;
  esac
  case "$_CS_INTERPRETERS" in
    *" $h "*) _cs_promote interpreter ;;
  esac
  return 0
}

# Parse `git [global-opts] <sub> [<sub2>]` -> _CS_GIT_SUB / _CS_GIT_SUB2.
_cs_git_parse() {
  _CS_GIT_SUB=""
  _CS_GIT_SUB2=""
  local -a seg=("$@")
  local i skip=0 t
  for ((i = 1; i < ${#seg[@]}; i++)); do
    t="${seg[$i]}"
    if [ "$skip" -eq 1 ]; then
      skip=0
      continue
    fi
    case "$t" in
      -C|-c) skip=1 ;;
      -*) : ;;
      *)
        if [ -z "$_CS_GIT_SUB" ]; then
          _CS_GIT_SUB="$t"
        else
          _CS_GIT_SUB2="$t"
          break
        fi
        ;;
    esac
  done
  return 0
}

# Find the effective head of a segment: skip leading redirections, shell
# keywords (do/then/if/...), VAR=val assignments, and simple wrappers
# (env/nice/nohup/...). `for`/`select` segments are pure iteration setup with
# no command execution -> empty head.
_cs_segment_head() {
  local -a seg=("$@")
  local n=${#seg[@]} i=0 tok
  while [ "$i" -lt "$n" ]; do
    tok="${seg[$i]}"
    case "$tok" in
      '>'|'>>'|'&>'|'>&'|'<') i=$((i + 2)); continue ;;
      for|select) return 0 ;;
      if|then|elif|else|while|until|do|'{'|'!') i=$((i + 1)); continue ;;
    esac
    if [[ "$tok" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      i=$((i + 1)); continue
    fi
    case "$tok" in
      timeout)
        # Skip `timeout [flags] DURATION` so the wrapped command is the head.
        i=$((i + 1))
        while [ "$i" -lt "$n" ]; do
          case "${seg[$i]}" in
            -*) i=$((i + 1)) ;;
            *) break ;;
          esac
        done
        i=$((i + 1))
        continue ;;
      env|nice|nohup|time|stdbuf|setsid)
        i=$((i + 1))
        while [ "$i" -lt "$n" ]; do
          case "${seg[$i]}" in
            -*) i=$((i + 1)) ;;
            *=*) if [[ "${seg[$i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); else break; fi ;;
            *) break ;;
          esac
        done
        continue ;;
      *) printf '%s' "$tok"; return 0 ;;
    esac
  done
  return 0
}

# Is a python invocation an inline one-liner? True for version flags and any
# `-c <code>` one-liner: the code is visible in the transcript and bounded by
# the Bash tool timeout, so it counts as inline inspection under this
# workspace's transparency posture (not a containment boundary -- same
# acceptance class as the native awk/sed allowlist). Scripts, `-m` modules,
# and bare REPLs are the long-running class and stay on tmux.
_cs_py_probe() {
  local -a args=("$@")
  local i=0 n=${#args[@]} t
  while [ "$i" -lt "$n" ]; do
    t="${args[$i]}"
    case "$t" in
      -B|-E|-I|-s|-u) i=$((i + 1)); continue ;;
      -V|-VV|--version) return 0 ;;
      -c)
        [ -n "${args[$((i + 1))]:-}" ] && return 0
        return 1 ;;
      *) return 1 ;;
    esac
  done
  return 1
}

# Classify one segment: promote sudo/interpreter, downgrade cleanliness.
_cs_handle_segment() {
  [ "$#" -gt 0 ] || return 0
  local -a seg=("$@")
  local head base a t vn

  # Record leading VAR=value assignments; forget a name on dynamic
  # reassignment so a stale literal can never resolve a later head.
  for t in "${seg[@]}"; do
    if [[ "$t" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      vn="${BASH_REMATCH[1]}"
      case "${BASH_REMATCH[2]}" in
        *'$'*|*'`'*) unset "_CS_ASSIGN[$vn]" ;;
        *) _CS_ASSIGN["$vn"]="${BASH_REMATCH[2]}" ;;
      esac
      continue
    fi
    break
  done

  head="$(_cs_segment_head "${seg[@]}")"
  [ -n "$head" ] || return 0

  # Resolve a simple variable head from a recorded assignment:
  # TC=/path/tool.sh ... "$TC" send ...
  if [[ "$head" =~ ^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?$ ]]; then
    vn="${BASH_REMATCH[1]}"
    if [ -n "${_CS_ASSIGN[$vn]:-}" ]; then
      head="${_CS_ASSIGN[$vn]}"
      # access_guard scans the UNEXPANDED tokens, so a mutator reached
      # through a variable has an invisible target scan: never clean.
      case " $_CS_MUTATOR_HEADS " in
        *" ${head##*/} "*) _CS_CLEAN=0; return 0 ;;
      esac
    fi
  fi

  # A dynamic head ($CMD, `...`) is never statically classifiable.
  case "$head" in
    *'$'*|*'`'*) _CS_CLEAN=0; return 0 ;;
  esac

  # Sanctioned harness entrypoints: they perform their own classification.
  case "$head" in
    *".claude/harness/run.sh"|*".claude/skills/tmux-control/scripts/tmux_control.sh")
      return 0 ;;
  esac

  base="${head##*/}"
  case "$base" in
    sudo)
      _cs_promote sudo
      return 0 ;;
    bash|sh|dash|zsh)
      local j has_c=0 inner=""
      for ((j = 1; j < ${#seg[@]}; j++)); do
        if [ "${seg[$j]}" = "-c" ]; then
          has_c=1
          inner="${seg[$((j + 1))]:-}"
          break
        fi
      done
      if [ "$has_c" -eq 1 ] && [ -n "$inner" ]; then
        # `bash -c '<inner>'` -> classify the inner command itself.
        local -a inner_toks=()
        mapfile -t inner_toks < <(tokenize_command "$inner")
        [ "${#inner_toks[@]}" -gt 0 ] && _cs_scan_tokens "${inner_toks[@]}"
      else
        # `bash script.sh` -> opaque script execution.
        _CS_CLEAN=0
      fi
      return 0 ;;
    git)
      _cs_git_parse "${seg[@]}"
      case "$_CS_GIT_SUB" in
        clone|pull|checkout|switch)
          _cs_promote interpreter
          _CS_CLEAN=0 ;;
        worktree)
          case "$_CS_GIT_SUB2" in
            list|lock|unlock) : ;;
            *) _cs_promote interpreter; _CS_CLEAN=0 ;;
          esac ;;
        push|reset)
          # Native ask rules own these (git push / git reset --hard).
          _CS_FORCE_NATIVE=1 ;;
        *)
          case " $_CS_GIT_RO " in
            *" $_CS_GIT_SUB "*) : ;;
            *) _CS_CLEAN=0 ;;
          esac ;;
      esac
      return 0 ;;
    command)
      # `command -v X` / `command -V X` are lookups (read-only).
      a=""
      for t in "${seg[@]:1}"; do
        case "$t" in
          -v|-V) return 0 ;;
          -*) : ;;
          *) a="$t"; break ;;
        esac
      done
      [ -n "$a" ] || return 0
      # `command X ...` runs X: classify X as the head.
      _cs_class_head "$a"
      case " $_CS_SAFE_HEADS " in
        *" ${a##*/} "*) : ;;
        *) _CS_CLEAN=0 ;;
      esac
      return 0 ;;
    type)
      return 0 ;;
    pip|pip2|pip3)
      # Read-only pip queries run inline; installs/uninstalls and anything
      # env-mutating still route to tmux (blocking, opaque, worth watching).
      a=""
      for t in "${seg[@]:1}"; do
        case "$t" in
          -*) : ;;
          *) a="$t"; break ;;
        esac
      done
      case "$a" in
        show|list|freeze|check|inspect|debug|help) return 0 ;;
      esac
      _cs_promote interpreter
      return 0 ;;
    python|python2|python3)
      # One-liners (python -V, python -c <code>) run inline; scripts, -m
      # modules, and REPLs still route to tmux.
      if _cs_py_probe "${seg[@]:1}"; then
        return 0
      fi
      _cs_promote interpreter
      return 0 ;;
    source|.)
      # The canonical env activation from .claude/ENV.md
      # (`source ~/miniconda3/bin/activate ENV`) is read-only env setup.
      # Sourcing anything else executes opaque script content.
      a="${seg[1]:-}"
      case "${a##*/}" in
        activate) return 0 ;;
      esac
      _CS_CLEAN=0
      return 0 ;;
    *)
      _cs_class_head "$base"
      case " $_CS_INTERPRETERS " in
        *" $base "*) return 0 ;;
      esac
      case "$base" in
        bugsinpy-*) return 0 ;;
      esac
      case " $_CS_SAFE_HEADS " in
        *" $base "*) : ;;
        *) _CS_CLEAN=0 ;;
      esac
      return 0 ;;
  esac
}

# Walk tokens, split into segments on separators, classify each segment.
_cs_scan_tokens() {
  [ "$#" -gt 0 ] || return 0
  local -a toks=("$@") seg=()
  local n=${#toks[@]} i t
  for ((i = 0; i < n; i++)); do
    t="${toks[$i]}"
    if is_separator "$t"; then
      [ "${#seg[@]}" -gt 0 ] && _cs_handle_segment "${seg[@]}"
      seg=()
    else
      seg+=("$t")
    fi
  done
  [ "${#seg[@]}" -gt 0 ] && _cs_handle_segment "${seg[@]}"
  return 0
}

_cs_scan_reset() {
  _CS_CLASS="plain"
  _CS_CLEAN=1
  _CS_FORCE_NATIVE=0
  _CS_ASSIGN=()
  return 0
}

# True (0) when the command contains execution the token scan cannot see:
# backticks outside single quotes, or `$(` inside DOUBLE quotes (the tokenizer
# keeps double-quoted text as one literal token, but bash still executes the
# substitution). Unquoted `$(...)` is fine: `(`/`)` are separators, so its
# content is segmented and every inner head and write target gets scanned.
cs_has_hidden_exec() {
  local input="$1" len i ch quote="" escape=0 prev=""
  len="${#input}"
  for ((i = 0; i < len; i++)); do
    ch="${input:i:1}"
    if [ "$escape" -eq 1 ]; then
      escape=0
      prev=""
      continue
    fi
    if [ "$quote" = "'" ]; then
      [ "$ch" = "'" ] && quote=""
      prev=""
      continue
    fi
    if [ "$quote" = '"' ]; then
      case "$ch" in
        "\\") escape=1; prev="" ;;
        '"') quote=""; prev="" ;;
        '`') return 0 ;;
        '(') if [ "$prev" = '$' ]; then return 0; fi; prev="$ch" ;;
        *) prev="$ch" ;;
      esac
      continue
    fi
    case "$ch" in
      "\\") escape=1; prev="" ;;
      "'") quote="'"; prev="" ;;
      '"') quote='"'; prev="" ;;
      '`') return 0 ;;
      *) prev="$ch" ;;
    esac
  done
  return 1
}

cs_transparency_class() {
  _cs_scan_reset
  local -a toks=()
  mapfile -t toks < <(tokenize_command "$1")
  [ "${#toks[@]}" -gt 0 ] && _cs_scan_tokens "${toks[@]}"
  printf '%s\n' "$_CS_CLASS"
}

cs_decide() {
  _cs_scan_reset
  # Execution hidden from the token scan (quoted substitution, backticks)
  # is never auto-allowed. Unquoted $(...) is segmented and scanned.
  if cs_has_hidden_exec "$1"; then
    _CS_CLEAN=0
  fi
  local -a toks=()
  mapfile -t toks < <(tokenize_command "$1")
  [ "${#toks[@]}" -gt 0 ] && _cs_scan_tokens "${toks[@]}"
  if [ "$_CS_CLASS" = "sudo" ]; then
    printf 'sudo\n'
  elif [ "$_CS_CLASS" = "interpreter" ]; then
    printf 'interpreter\n'
  elif [ "$_CS_FORCE_NATIVE" -eq 1 ]; then
    printf 'native\n'
  elif [ "$_CS_CLEAN" -eq 1 ]; then
    printf 'clean\n'
  else
    printf 'opaque\n'
  fi
}
