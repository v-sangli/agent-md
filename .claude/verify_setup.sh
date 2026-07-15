#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-$(pwd)}"
REPO_DIR="$(cd "$REPO_DIR" && pwd)"

# Hermetic default-deny config dir. Permission-classification tests point
# CLAUDE_PROJECT_DIR here so they validate guard LOGIC independent of the
# machine-local .claude/access.conf grants. (Scripts still load from REPO_DIR.)
DEFAULT_CFG_DIR="$(mktemp -d)"
mkdir -p "$DEFAULT_CFG_DIR/.claude"
printf 'allow_external_write=false\nallow_external_delete=false\nmaintainer_mode=false\n' \
  >"$DEFAULT_CFG_DIR/.claude/access.conf"
trap 'rm -rf "$DEFAULT_CFG_DIR"' EXIT

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
  printf 'PASS | %s\n' "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL | %s\n' "$1"
}

need_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    pass "command exists: $name"
  else
    fail "missing command: $name"
  fi
}

need_file() {
  local p="$1"
  if [ -f "$REPO_DIR/$p" ]; then
    pass "file exists: $p"
  else
    fail "missing file: $p"
  fi
}

need_absent() {
  local p="$1"
  if [ ! -e "$REPO_DIR/$p" ]; then
    pass "absent: $p"
  else
    fail "should be absent: $p"
  fi
}

need_exec() {
  local p="$1"
  if [ -x "$REPO_DIR/$p" ]; then
    pass "executable: $p"
  else
    fail "not executable: $p"
  fi
}

run_expect() {
  local name="$1"
  local expected="$2"
  shift 2
  set +e
  "$@" >/tmp/verify_setup.out 2>/tmp/verify_setup.err
  local rc=$?
  set -e
  if [ "$rc" -eq "$expected" ]; then
    pass "$name (exit=$rc)"
  else
    fail "$name (expected=$expected got=$rc)"
    sed -n '1,40p' /tmp/verify_setup.err | sed 's/^/  stderr: /'
    sed -n '1,30p' /tmp/verify_setup.out | sed 's/^/  stdout: /'
  fi
}

check_skill_md() {
  local path="$1" label="$2" frontmatter
  if [ "$(head -n 1 "$path")" != "---" ]; then
    printf 'missing opening frontmatter: %s\n' "$label"
    return 1
  fi
  if ! tail -n +2 "$path" | rg -q '^---$'; then
    printf 'missing closing frontmatter: %s\n' "$label"
    return 1
  fi
  frontmatter="$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$path")"
  printf '%s\n' "$frontmatter" | rg -q '^name:[[:space:]]*.+' || {
    printf 'missing name: %s\n' "$label"
    return 1
  }
  printf '%s\n' "$frontmatter" | rg -q '^description:[[:space:]]*.+' || {
    printf 'missing description: %s\n' "$label"
    return 1
  }
}

printf 'Verifying repo: %s\n' "$REPO_DIR"

need_command jq
need_command rg
need_command realpath

need_file ".claude/access.conf"
need_file ".claude/ENV.md"
need_file ".claude/policy/AGENT_RULES.md"
need_file ".claude/policy/OPERATING_SPEC.md"
need_file ".claude/settings.json"
need_file ".claude/harness/run.sh"
need_file ".claude/hooks/access_guard.sh"
need_file ".claude/hooks/lib/command_scan.sh"
need_file ".claude/hooks/session_start.sh"
need_file ".claude/hooks/pre_tool_use_guard.sh"
need_file ".claude/hooks/pre_tool_use_bash_guard.sh"
need_file ".claude/hooks/post_tool_use_privilege_guard.sh"
need_file ".claude/skills/tmux-control/SKILL.md"
need_file ".claude/skills/tmux-control/references/commands.md"
need_file ".claude/skills/tmux-control/references/sudo.md"
need_file ".claude/skills/tmux-control/references/validation.md"
need_file ".claude/skills/tmux-control/scripts/tmux_control.sh"
need_file ".claude/skills/dx/.claude-plugin/plugin.json"
need_file ".claude/skills/dx/CLAUDE.md"
need_file ".claude/skills/dx/GLOBAL-CLAUDE.md"
need_file ".claude/skills/dx/skills/handoff/SKILL.md"
need_file ".claude/skills/dx/skills/clone/SKILL.md"
need_file ".claude/skills/superpowers/.claude-plugin/plugin.json"
need_file ".claude/skills/superpowers/CLAUDE.md"
need_file ".claude/skills/superpowers/AGENTS.md"
need_file ".claude/skills/superpowers/skills/using-superpowers/SKILL.md"
need_file ".claude/skills/superpowers/skills/brainstorming/SKILL.md"

need_absent ".claude-log"
need_absent ".claude-tools"
need_absent ".claude/spec_hashes.json"
need_absent ".claude/skills/clone"
need_absent ".claude/skills/half-clone"
need_absent ".claude/skills/handoff"
need_absent ".claude/skills/gha"
need_absent ".claude/skills/hn-summarize"
need_absent ".claude/skills/reddit-fetch"
need_absent ".claude/skills/review-claudemd"
need_absent ".claude/skills/version-check"

need_exec ".claude/hooks/access_guard.sh"
need_exec ".claude/harness/run.sh"
need_exec ".claude/hooks/session_start.sh"
need_exec ".claude/hooks/pre_tool_use_guard.sh"
need_exec ".claude/hooks/pre_tool_use_bash_guard.sh"
need_exec ".claude/hooks/post_tool_use_privilege_guard.sh"
need_exec ".claude/skills/tmux-control/scripts/tmux_control.sh"

if jq -e '
  (.hooks.SessionStart != null) and
  (.hooks.PreToolUse != null) and
  (.hooks.PostToolUse != null) and
  (.hooks.PostToolUseFailure != null) and
  ((.permissions.allow // []) | index("Bash(*)") | not) and
  ((.permissions.allow // []) | index("Bash") != null) and
  ((.permissions.allow // []) | index("Bash(.claude/harness/run.sh:*)") != null) and
  ((.permissions.ask // []) | index("Bash(rm -rf:*)") | not) and
  ((.permissions.deny // []) | index("Edit(.claude/**)") | not) and
  ((.permissions.deny // []) | index("Write(.claude/**)") | not) and
  ([.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command] | index("bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/access_guard.sh\"") | not)
' "$REPO_DIR/.claude/settings.json" >/dev/null; then
  pass "settings.json routes Bash mutation through harness, not access-guard allow"
else
  fail "settings.json routes Bash mutation through harness, not access-guard allow"
fi

# Hook commands must be CWD-independent: a persisted `cd` out of the workspace
# made relative `bash .claude/hooks/...` registrations fail silently
# (non-blocking "No such file or directory"), leaving Bash calls unguarded.
if jq -e '
  [.hooks | to_entries[] | .value[] | .hooks[] | .command]
  | (length > 0) and all(startswith("bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/"))
' "$REPO_DIR/.claude/settings.json" >/dev/null; then
  pass "settings.json hook commands are CWD-independent via \$CLAUDE_PROJECT_DIR"
else
  fail "settings.json hook commands are CWD-independent via \$CLAUDE_PROJECT_DIR"
fi

standalone_names=""
plugin_skill_names=""
plugin_skill_count=0
skill_bad=0
shopt -s nullglob
for entry in "$REPO_DIR/.claude/skills"/*; do
  [ -d "$entry" ] || continue
  name="$(basename "$entry")"
  if [ -f "$entry/SKILL.md" ]; then
    standalone_names+="$name"$'\n'
    check_skill_md "$entry/SKILL.md" "$name/SKILL.md" || skill_bad=1
  elif [ -f "$entry/.claude-plugin/plugin.json" ]; then
    jq -e '.name and (.name != "")' "$entry/.claude-plugin/plugin.json" >/dev/null || {
      printf 'plugin manifest missing name: %s\n' "$name"
      skill_bad=1
    }
    nested=( "$entry"/skills/*/SKILL.md )
    if [ "${#nested[@]}" -eq 0 ]; then
      printf 'plugin has no nested skills: %s\n' "$name"
      skill_bad=1
    fi
    for skill_path in "${nested[@]}"; do
      skill_name="$(basename "$(dirname "$skill_path")")"
      plugin_skill_names+="$name:$skill_name"$'\n'
      plugin_skill_count=$((plugin_skill_count + 1))
      check_skill_md "$skill_path" "$name/skills/$skill_name/SKILL.md" || skill_bad=1
    done
  else
    printf 'neither standalone skill nor plugin: %s\n' "$name"
    skill_bad=1
  fi
done
shopt -u nullglob

if printf '%s' "$standalone_names" | rg -qx 'tmux-control' &&
  [ "$plugin_skill_count" -ge 22 ] &&
  printf '%s' "$plugin_skill_names" | rg -qx 'superpowers:using-superpowers' &&
  printf '%s' "$plugin_skill_names" | rg -qx 'dx:handoff' &&
  [ "$skill_bad" -eq 0 ]; then
  pass "standalone skills and project-scope plugins have Claude-compatible metadata"
else
  fail "standalone skills and project-scope plugins have Claude-compatible metadata"
fi

claude_ok=1
for required in \
  "## Karpathy guidelines" \
  "### 1. Think before coding" \
  "### 2. Simplicity first" \
  "### 3. Surgical changes" \
  "### 4. Goal-driven execution"; do
  rg -Fq "$required" "$REPO_DIR/CLAUDE.md" || claude_ok=0
done
if [ "$claude_ok" -eq 1 ]; then
  pass "CLAUDE.md contains distilled Karpathy guidance"
else
  fail "CLAUDE.md contains distilled Karpathy guidance"
fi

env_ok=1
for required in \
  "source /data/miniconda3/bin/activate dexpolicy" \
  "python -V" \
  "which python" \
  ".claude/policy/AGENT_RULES.md"; do
  rg -Fq "$required" "$REPO_DIR/.claude/ENV.md" || env_ok=0
done
for required in \
  "AGENT_RULES.md" \
  "OPERATING_SPEC.md" \
  ".claude/ENV.md"; do
  rg -Fq "$required" "$REPO_DIR/CLAUDE.md" || env_ok=0
done
if [ "$env_ok" -eq 1 ]; then
  pass "environment contract is restored and referenced"
else
  fail "environment contract is restored and referenced"
fi

policy_ok=1
for required in \
  "## Non-Negotiables" \
  ".claude/harness/run.sh" \
  "tmux-control" \
  ".claude/ENV.md" \
  "PYTHONPATH=."; do
  rg -Fq "$required" "$REPO_DIR/.claude/policy/AGENT_RULES.md" || policy_ok=0
done
for required in \
  "Version: 2.1" \
  "canonical rule source" \
  ".claude/harness/run.sh" \
  ".claude/access.conf" \
  "tmux-control" \
  ".claude/ENV.md" \
  "Policy hash drift blocking is not active"; do
  rg -Fq "$required" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md" || policy_ok=0
done
if rg -Fq ".claude-log" "$REPO_DIR/.claude/policy/AGENT_RULES.md" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md" ||
  rg -Fq ".claude-tools" "$REPO_DIR/.claude/policy/AGENT_RULES.md" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md" ||
  rg -Fq "spec_hashes.json" "$REPO_DIR/.claude/policy/AGENT_RULES.md" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md"; then
  policy_ok=0
fi
if [ "$policy_ok" -eq 1 ]; then
  pass "policy docs are restored for the lean harness"
else
  fail "policy docs are restored for the lean harness"
fi

ss_out="$(printf '{"session_id":"verify"}' | CLAUDE_PROJECT_DIR="$REPO_DIR" bash "$REPO_DIR/.claude/hooks/session_start.sh")"
for key in "STATE REINJECTION" "SESSION_ID:" "RULE SOURCES:" "POINTERS:"; do
  if printf '%s\n' "$ss_out" | rg -q "$key"; then
    pass "session_start output contains $key"
  else
    fail "session_start output missing $key"
  fi
done
if printf '%s\n' "$ss_out" | rg -q ".claude-log|.claude-tools|BugsInPy"; then
  fail "session_start output still references removed scaffolding"
else
  pass "session_start output avoids removed scaffolding"
fi

# --- context engine: session_start reseed ---
SS=".claude/hooks/session_start.sh"
if [ -x "$REPO_DIR/$SS" ]; then
  mkdir -p "$REPO_DIR/.claude/context/state"
  echo "RESEED-MARKER-123" > "$REPO_DIR/.claude/context/state/recap.md"
  out="$(printf '{"session_id":"testsid","source":"startup"}' | CLAUDE_PROJECT_DIR="$REPO_DIR" "$REPO_DIR/$SS" 2>/dev/null || true)"
  printf '%s' "$out" | grep -q 'RESEED-MARKER-123' && pass "session_start injects recap on startup" || fail "session_start reseed (got: $out)"
  [ ! -f "$REPO_DIR/.claude/context/state/recap.md" ] && pass "session_start consumes recap one-shot" || fail "recap not consumed"
  rm -f "$REPO_DIR/.claude/context/state/"recap.*.consumed

  # FIX 2: source="clear" is not startup/resume -> must not reseed, even
  # though jq is present and recap.md exists.
  echo "RESEED-MARKER-CLEAR" > "$REPO_DIR/.claude/context/state/recap.md"
  out_clear="$(printf '{"session_id":"x","source":"clear"}' | CLAUDE_PROJECT_DIR="$REPO_DIR" "$REPO_DIR/$SS" 2>/dev/null || true)"
  printf '%s' "$out_clear" | grep -q 'RESEED-MARKER-CLEAR' && fail "session_start reseeded on source=clear (got: $out_clear)" || pass "session_start does not reseed on source=clear"
  [ -f "$REPO_DIR/.claude/context/state/recap.md" ] && pass "session_start leaves recap.md unconsumed on source=clear" || fail "recap.md was consumed on source=clear"
  rm -f "$REPO_DIR/.claude/context/state/recap.md" "$REPO_DIR/.claude/context/state/"recap.*.consumed
fi

run_expect "access classifier asks for .claude write" 0 bash -lc '
repo="$1"; cfg="$2"
jq -n --arg path ".claude/settings.json" "{tool_name:\"Write\",tool_input:{file_path:\$path}}" |
  CLAUDE_PROJECT_DIR="$cfg" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_claude.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_claude.out >/dev/null &&
  rg -q "CRITICAL.*\\.claude" /tmp/verify_access_claude.out
' _ "$REPO_DIR" "$DEFAULT_CFG_DIR"
run_expect "access classifier marks workspace rm-rf as allow" 0 bash -lc '
repo="$1"
jq -n --arg cmd "rm -rf build/tmp && rm -rf .cache/foo" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_workspace.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"allow\"" /tmp/verify_access_workspace.out >/dev/null
' _ "$REPO_DIR"
run_expect "access classifier asks for mashed external rm-rf" 0 bash -lc '
repo="$1"; cfg="$2"
jq -n --arg cmd "mkdir -p build && rm -rf build/tmp && rm -rf /opt/foo" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$cfg" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_external.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_external.out >/dev/null &&
  rg -q "/opt/foo" /tmp/verify_access_external.out
' _ "$REPO_DIR" "$DEFAULT_CFG_DIR"
run_expect "access classifier marks /tmp content cleanup as allow" 0 bash -lc '
repo="$1"
jq -n --arg cmd "rm -rf /tmp/claude-test-cache" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_tmp_content.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"allow\"" /tmp/verify_access_tmp_content.out >/dev/null
' _ "$REPO_DIR"
run_expect "access classifier treats /tmp root delete as critical ask" 0 bash -lc '
repo="$1"
jq -n --arg cmd "rm -rf /tmp" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_tmp_root.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_tmp_root.out >/dev/null &&
  rg -q "CRITICAL.*tmp" /tmp/verify_access_tmp_root.out
' _ "$REPO_DIR"
run_expect "access classifier asks for external write" 0 bash -lc '
repo="$1"; cfg="$2"
jq -n --arg path "/opt/foo" "{tool_name:\"Write\",tool_input:{file_path:\$path}}" |
  CLAUDE_PROJECT_DIR="$cfg" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_write_external.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_write_external.out >/dev/null &&
  rg -q "/opt/foo" /tmp/verify_access_write_external.out
' _ "$REPO_DIR" "$DEFAULT_CFG_DIR"
run_expect "access classifier asks for dynamic rm target" 0 bash -lc '
repo="$1"
jq -n --arg cmd "rm -rf \"\$TARGET\"" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_dynamic.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_dynamic.out >/dev/null &&
  rg -q "dynamic|unresolved" /tmp/verify_access_dynamic.out
' _ "$REPO_DIR"

run_expect "pre_tool_use_bash_guard runs workspace rm-rf free (no routing)" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf build/tmp\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard runs workspace sed in-place free" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -i s/x/y/ file.txt\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard runs workspace redirection free" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat input.txt > out.txt\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard asks for external write/delete with grant hint" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /opt/foo\"}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_external_rm.out && jq -e '.hookSpecificOutput.permissionDecision == \"ask\"' /tmp/verify_external_rm.out >/dev/null && rg -q 'access.conf' /tmp/verify_external_rm.out && rg -q '/opt/foo' /tmp/verify_external_rm.out"
run_expect "pre_tool_use_bash_guard asks CRITICAL for .claude write" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo x > .claude/settings.json\"}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_claude_write.out && jq -e '.hookSpecificOutput.permissionDecision == \"ask\"' /tmp/verify_claude_write.out >/dev/null && rg -q 'CRITICAL' /tmp/verify_claude_write.out"
# Dynamic-only write targets fall through to the native engine (2026-07-15
# decision, HARNESS_CHECKLIST.md); a resolved external target still asks.
run_expect "pre_tool_use_bash_guard falls through on dynamic-only write targets" 0 bash -lc "out=\$(jq -n --arg c 'broken=\"\$(mktemp)\"; grep -v x f > \"\$broken\"; rm -f \"\$broken\"' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
run_expect "pre_tool_use_bash_guard still asks when resolved external accompanies dynamic" 0 bash -lc "jq -n --arg c 'rm -rf /opt/foo && rm -rf \"\$BROKEN\"' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_mixed_dyn.out && jq -e '.hookSpecificOutput.permissionDecision == \"ask\"' /tmp/verify_mixed_dyn.out >/dev/null && rg -q '/opt/foo' /tmp/verify_mixed_dyn.out"
# Read-only commands must NOT be blocked, even when they contain a discarded
# redirect or name an interpreter/tool as an argument.
run_expect "pre_tool_use_bash_guard allows read-only command with discarded redirect" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls -la foo 2>/dev/null\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard allows command -v lookup of interpreter" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"command -v bun\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard allows which lookup of interpreter" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"which bun\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard allows interpreter name as grep argument" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls | grep npm\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard allows one-shot bash -c print" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bash -c '\\''echo hi'\\''\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard denies bash -c interpreter toward tmux" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bash -c '\\''pytest -q'\\''\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_deny_bashc.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_deny_bashc.out >/dev/null"
run_expect "pre_tool_use_bash_guard denies non-first-listed interpreter (ruby)" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ruby -e puts\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_deny_ruby.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_deny_ruby.out >/dev/null"
run_expect "pre_tool_use_bash_guard handles subshell/separator-terminated read-only command" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"(ls foo)\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
# Single-decider allow/fall-through behavior.
run_expect "pre_tool_use_bash_guard emits allow for read-only compound" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls -la /tmp 2>/dev/null | grep foo && cat /etc/hostname\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_allow_ro.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_allow_ro.out >/dev/null"
run_expect "pre_tool_use_bash_guard emits allow for workspace write" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf build/tmp\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_allow_ws.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_allow_ws.out >/dev/null"
run_expect "pre_tool_use_bash_guard emits allow for loop over read-only heads" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"for f in a b; do grep -c pattern \$f; done\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_allow_loop.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_allow_loop.out >/dev/null"
run_expect "pre_tool_use_bash_guard emits allow for git -C read-only subcommand" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git -C sub/dir log --oneline -5 && git -C sub/dir worktree list\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_allow_git.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_allow_git.out >/dev/null"
run_expect "pre_tool_use_bash_guard falls through on git push (native ask rules)" 0 bash -lc "out=\$(printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin main\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
# Unquoted $(...) is segmented: inner heads and write targets are scanned.
run_expect "pre_tool_use_bash_guard allows unquoted substitution with /tmp rm" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \$(rm -rf /tmp/zzz)\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_subst_tmp.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_subst_tmp.out >/dev/null"
run_expect "pre_tool_use_bash_guard asks on unquoted substitution with external rm" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo \$(rm -rf /opt/foo)\"}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_subst_ext.out && jq -e '.hookSpecificOutput.permissionDecision == \"ask\"' /tmp/verify_subst_ext.out >/dev/null && rg -q '/opt/foo' /tmp/verify_subst_ext.out"
# Double-quoted substitution and backticks hide execution from the token scan.
run_expect "pre_tool_use_bash_guard keeps double-quoted substitution opaque" 0 bash -lc "out=\$(jq -n --arg c 'echo \"\$(rm -rf /opt/foo)\"' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
run_expect "pre_tool_use_bash_guard keeps backticks opaque" 0 bash -lc "out=\$(jq -n --arg c 'echo \`id\`' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
# Newline and & are command separators (fail-open regression tests).
run_expect "pre_tool_use_bash_guard asks on multiline external rm" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls /tmp\\\\nrm -rf /opt/foo\"}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_ml_rm.out && jq -e '.hookSpecificOutput.permissionDecision == \"ask\"' /tmp/verify_ml_rm.out >/dev/null && rg -q '/opt/foo' /tmp/verify_ml_rm.out"
run_expect "pre_tool_use_bash_guard asks on backgrounded external rm" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls & rm -rf /opt/foo\"}}' | CLAUDE_PROJECT_DIR='$DEFAULT_CFG_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_bg_rm.out && jq -e '.hookSpecificOutput.permissionDecision == \"ask\"' /tmp/verify_bg_rm.out >/dev/null && rg -q '/opt/foo' /tmp/verify_bg_rm.out"
run_expect "pre_tool_use_bash_guard allows commented-out mutation plus read-only line" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"# scratch: rm -rf /opt/foo\\\\nls -la\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_comment.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_comment.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows fd-duplication 2>&1" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls /tmp 2>&1 | head -3\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_fddup.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_fddup.out >/dev/null"
# Variable-alias heads (TC=/path/tool.sh ... "$TC" args).
run_expect "pre_tool_use_bash_guard allows var-alias of sanctioned tmux helper" 0 bash -lc "jq -n --arg c 'TC=$REPO_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh
\$TC capture --target t::run --lines 5' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_alias_tc.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_alias_tc.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows tmux poll loop idiom" 0 bash -lc "jq -n --arg c 'TC=$REPO_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh; for i in \$(seq 1 2); do out=\$(\$TC status 2>/dev/null); echo \$out | grep -q pane && break; sleep 1; done; echo \$out | tail -2' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_poll.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_poll.out >/dev/null"
run_expect "pre_tool_use_bash_guard never allows mutator through var alias" 0 bash -lc "out=\$(jq -n --arg c 'R=rm
\$R -rf /opt/foo' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
run_expect "pre_tool_use_bash_guard forgets alias on dynamic reassignment" 0 bash -lc "out=\$(jq -n --arg c 'R=ls
R=\$HOME/x
\$R /opt' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
run_expect "tmux-control wait-for validates required options" 2 bash -lc "'$REPO_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh' wait-for --pattern x"
run_expect "tmux-control run validates required options" 2 bash -lc "'$REPO_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh' run --command x"
run_expect "tmux-control wait-for rejects pattern+run-id combo" 2 bash -lc "'$REPO_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh' wait-for --target x::y --pattern a --run-id b"
# Read-only interpreter probes run inline; real interpreter work stays on tmux.
run_expect "pre_tool_use_bash_guard allows python version probe" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python -V\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pyver.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_pyver.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows python import probe" 0 bash -lc "jq -n --arg c 'python -c \"import dexdata_rs\"' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pyimp.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_pyimp.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows python prefix probe" 0 bash -lc "jq -n --arg c 'python3 -c \"import sys; print(sys.prefix)\"' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pypfx.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_pypfx.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows any python -c one-liner" 0 bash -lc "jq -n --arg c 'python -c \"import sys; print(1, sys.prefix)\"' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pyone.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_pyone.out >/dev/null"
run_expect "pre_tool_use_bash_guard denies python script execution" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python bench.py\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pyscript.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_pyscript.out >/dev/null"
run_expect "pre_tool_use_bash_guard denies python -m module runs" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python -m pytest -q\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pymod.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_pymod.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows pip show query" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pip show dexdata | grep -iE Location\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pipshow.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_pipshow.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows abs-path pip list" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"/data/miniconda3/envs/dexpolicy/bin/pip list 2>/dev/null | head -5\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_piplist.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_piplist.out >/dev/null"
run_expect "pre_tool_use_bash_guard denies pip download" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pip download requests\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_pipdl.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_pipdl.out >/dev/null"
run_expect "pre_tool_use_bash_guard denies maturin toward tmux" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"maturin develop --release\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_maturin.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_maturin.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows source-activate env probe chain" 0 bash -lc "jq -n --arg c 'source ~/miniconda3/bin/activate dexpolicy && python -V && python -c \"import sys; print(sys.prefix)\"' '{tool_name:\"Bash\",tool_input:{command:\$c}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_srcact.out && jq -e '.hookSpecificOutput.permissionDecision == \"allow\"' /tmp/verify_srcact.out >/dev/null"
run_expect "pre_tool_use_bash_guard keeps generic source opaque" 0 bash -lc "out=\$(printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"source setup_env.sh\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
run_expect "pre_tool_use_bash_guard falls through on unknown head" 0 bash -lc "out=\$(printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sometool --flag arg\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'); [ -z \"\$out\" ]"
run_expect "harness runner executes workspace rm-rf" 0 bash -lc "cd '$REPO_DIR' && rm -rf .verify-harness && mkdir -p .verify-harness/child && .claude/harness/run.sh -- 'rm -rf .verify-harness/child' && test ! -e .verify-harness/child && rm -rf .verify-harness"
run_expect "harness runner executes safe /tmp cleanup" 0 bash -lc "mkdir -p /tmp/claude-harness-verify && '$REPO_DIR/.claude/harness/run.sh' -- 'rm -rf /tmp/claude-harness-verify' && test ! -e /tmp/claude-harness-verify"
# run.sh reads the LIVE access.conf (it cannot be pointed at the hermetic
# dir), so expect by the machine-local grant state: default-deny -> ask
# without running (3); granted -> executes (0).
if rg -q '^allow_external_delete=true' "$REPO_DIR/.claude/access.conf" 2>/dev/null; then
  run_expect "harness runner executes external delete under live grant" 0 bash -lc "cd '$REPO_DIR'; .claude/harness/run.sh -- 'rm -rf /opt/claude-harness-test'"
else
  run_expect "harness runner asks for external delete without running" 3 bash -lc "cd '$REPO_DIR'; set +e; .claude/harness/run.sh -- 'rm -rf /opt/claude-harness-test' 2>/tmp/verify_harness_external.err; rc=\$?; set -e; rg -q 'Approval required' /tmp/verify_harness_external.err; exit \$rc"
fi
run_expect "harness runner treats critical delete as non-running request" 4 bash -lc "cd '$REPO_DIR'; set +e; .claude/harness/run.sh -- 'rm -rf /tmp' 2>/tmp/verify_harness_critical.err; rc=\$?; set -e; rg -q 'Critical approval required' /tmp/verify_harness_critical.err; exit \$rc"
run_expect "harness runner asks for dynamic target without running" 3 bash -lc "cd '$REPO_DIR'; set +e; .claude/harness/run.sh -- 'rm -rf \"\$TARGET\"' 2>/tmp/verify_harness_dynamic.err; rc=\$?; set -e; rg -q 'dynamic|unresolved' /tmp/verify_harness_dynamic.err; exit \$rc"

run_expect "pre_tool_use_bash_guard denies pip install toward tmux" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pip install requests\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_deny_pip.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_deny_pip.out >/dev/null && rg -q 'tmux-control' /tmp/verify_deny_pip.out"
run_expect "pre_tool_use_bash_guard denies compound install after rm-rf" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf build && pip install requests\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_deny_compound.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_deny_compound.out >/dev/null"
run_expect "pre_tool_use_bash_guard denies sudo toward root-request" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sudo true\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_sudo_redirect.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_sudo_redirect.out >/dev/null && rg -q 'root-request' /tmp/verify_sudo_redirect.out"
run_expect "pre_tool_use_bash_guard denies direct pytest toward tmux" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pytest -q\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' >/tmp/verify_deny_pytest.out && jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' /tmp/verify_deny_pytest.out >/dev/null"
run_expect "pre_tool_use_bash_guard allows tmux-control helper" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\".claude/skills/tmux-control/scripts/tmux_control.sh send --target smoke::run --command '\\''pytest -q'\\''\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard allows root-request with sudo argument" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\".claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-verify --cwd . --command '\\''sudo true'\\''\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "tmux-control root request only offers root tmux" 0 bash -lc "cd '$REPO_DIR' && .claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-verify --cwd '$REPO_DIR' --command 'sudo true' >/tmp/verify_root_request.out && rg -q 'approve a visible root tmux session' /tmp/verify_root_request.out && rg -q 'real terminal' /tmp/verify_root_request.out && ! rg -q 'Option 1|paste the output|in-session ! sudo.*alternative' /tmp/verify_root_request.out"
run_expect "post_tool_use_privilege_guard injects root guidance" 0 bash -lc "printf '{\"hook_event_name\":\"PostToolUseFailure\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"dmesg | tail\"},\"error\":\"dmesg: read kernel buffer failed: Operation not permitted\"}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/post_tool_use_privilege_guard.sh' >/tmp/verify_privilege_hook.out && jq -e . /tmp/verify_privilege_hook.out >/dev/null && rg -q 'root-request' /tmp/verify_privilege_hook.out && rg -q 'true equivalent' /tmp/verify_privilege_hook.out && rg -q 'Do not suggest in-session' /tmp/verify_privilege_hook.out"
run_expect "post_tool_use_privilege_guard ignores privilege words in stdout" 0 bash -lc "out=\$(printf '{\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat notes.txt\"},\"tool_response\":{\"stdout\":\"docs say: Operation not permitted means EPERM\",\"stderr\":\"\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/post_tool_use_privilege_guard.sh'); [ -z \"\$out\" ]"
run_expect "post_tool_use_privilege_guard fires on stderr denial" 0 bash -lc "printf '{\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat /root/x\"},\"tool_response\":{\"stdout\":\"\",\"stderr\":\"cat: /root/x: Permission denied\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/post_tool_use_privilege_guard.sh' >/tmp/verify_priv_stderr.out && jq -e . /tmp/verify_priv_stderr.out >/dev/null && rg -q 'root-request' /tmp/verify_priv_stderr.out"

# --- context engine: ctxgauge composition ---
CTXG=".claude/context/ctxgauge.sh"
FIX=".claude/context/fixtures/sample_session.jsonl"
need_exec "$CTXG"
if [ -x "$REPO_DIR/$CTXG" ]; then
  comp="$("$REPO_DIR/$CTXG" composition "$REPO_DIR/$FIX" 2>/dev/null || echo '{}')"
  cap="$(printf '%s' "$comp" | jq -r '.capsules // "x"')"
  tr="$(printf '%s' "$comp" | jq -r '.tool_results // "x"')"
  ti="$(printf '%s' "$comp" | jq -r '.tool_inputs // "x"')"
  [ "$cap" = "28" ] && pass "ctxgauge capsules=28" || fail "ctxgauge capsules (got $cap want 28)"
  [ "$tr" = "12" ]  && pass "ctxgauge tool_results excludes mirror (=12)" || fail "ctxgauge tool_results (got $tr want 12)"
  [ "$ti" = "84" ]  && pass "ctxgauge tool_inputs=84" || fail "ctxgauge tool_inputs (got $ti want 84)"
fi

# --- context engine: ctxgauge perfile ---
if [ -x "$REPO_DIR/$CTXG" ]; then
  pf="$("$REPO_DIR/$CTXG" perfile "$REPO_DIR/$FIX" 2>/dev/null || echo '[]')"
  foo_edits="$(printf '%s' "$pf" | jq -r '[.[]|select(.path=="/x/foo.sh")|.edits]|add // 0')"
  [ "$foo_edits" = "1" ] && pass "ctxgauge perfile foo.sh edits=1" || fail "ctxgauge perfile edits (got $foo_edits want 1)"
fi

# --- context engine: ctxgauge tokens ---
if [ -x "$REPO_DIR/$CTXG" ]; then
  tk="$("$REPO_DIR/$CTXG" tokens "$REPO_DIR/$FIX" 2>/dev/null || echo '{}')"
  cb="$(printf '%s' "$tk" | jq -r '.context_bytes // "x"')"
  # sum of known composition: prose12 + capsules28 + tool_results12 + user5 + tool_inputs84 = 141
  [ "$cb" = "141" ] && pass "ctxgauge tokens context_bytes=141" || fail "ctxgauge tokens context_bytes (got $cb)"
fi

# --- context engine: capsules-by-phase ---
if [ -x "$REPO_DIR/$CTXG" ]; then
  cbp="$("$REPO_DIR/$CTXG" capsules-by-phase "$REPO_DIR/$FIX" 2>/dev/null || echo '{}')"
  bucket="$(printf '%s' "$cbp" | jq -r '."2026-07-14T10" // "x"')"
  [ "$bucket" = "28" ] && pass "capsules-by-phase 10h bucket=28" || fail "capsules-by-phase (got $bucket want 28)"
fi

# --- context engine: externalization signal ---
EXT=".claude/hooks/lib/externalization.sh"
need_file "$EXT"
if [ -f "$REPO_DIR/$EXT" ]; then
  ( set +e
    # shellcheck disable=SC1090
    . "$REPO_DIR/$EXT"
    tmpf="$(mktemp)"; now="$(stat -c %Y "$tmpf")"
    externalized_since "$((now-10))" "$tmpf"; a=$?
    externalized_since "$((now+100))" "$tmpf"; b=$?
    rm -f "$tmpf"
    [ "$a" -eq 0 ] && [ "$b" -eq 1 ] && echo "PASS | externalized_since past=hit future=miss" || echo "FAIL | externalized_since (past=$a future=$b)"
  ) | while read -r line; do case "$line" in PASS*) pass "${line#PASS | }";; FAIL*) fail "${line#FAIL | }";; esac; done
fi

# --- context engine: ctxgauge evictable ---
if [ -x "$REPO_DIR/$CTXG" ]; then
  ev="$("$REPO_DIR/$CTXG" evictable "$REPO_DIR/$FIX" 2>/dev/null || echo '{}')"
  n="$(printf '%s' "$ev" | jq -r '.evictable_tokens // "x"')"
  case "$n" in ''|*[!0-9]*) fail "ctxgauge evictable numeric (got $n)";; *) pass "ctxgauge evictable_tokens=$n";; esac
fi

# --- context engine: stop gauge hook ---
SGH=".claude/hooks/stop_context_gauge.sh"
need_exec "$SGH"
if [ -x "$REPO_DIR/$SGH" ]; then
  # tiny fixture, low fraction -> no nudge
  out="$(printf '{"transcript_path":"%s","hook_event_name":"Stop"}' "$REPO_DIR/$FIX" | CTX_NUDGE_FRACTION=0.55 "$REPO_DIR/$SGH" 2>/dev/null || true)"
  [ -z "$out" ] && pass "stop gauge silent under threshold" || fail "stop gauge should be silent (got: $out)"
  # force threshold to 0 -> must nudge
  out2="$(printf '{"transcript_path":"%s","hook_event_name":"Stop"}' "$REPO_DIR/$FIX" | CTX_NUDGE_FRACTION=0 "$REPO_DIR/$SGH" 2>/dev/null || true)"
  printf '%s' "$out2" | grep -qi 'context' && pass "stop gauge nudges over threshold" || fail "stop gauge should nudge (got: $out2)"
fi

# --- context engine: stop gauge handoff mode ---
if [ -x "$REPO_DIR/$SGH" ]; then
  rm -f "$REPO_DIR/.claude/context/state/handoff.pending" "$REPO_DIR/.claude/context/state/recap.md"
  printf '{"transcript_path":"%s","hook_event_name":"Stop"}' "$REPO_DIR/$FIX" \
    | CTX_NUDGE_FRACTION=0 CTX_HANDOFF_MODE=1 CLAUDE_PROJECT_DIR="$REPO_DIR" "$REPO_DIR/$SGH" >/dev/null 2>&1 || true
  [ -f "$REPO_DIR/.claude/context/state/handoff.pending" ] && pass "handoff mode drops sentinel" || fail "no handoff.pending"
  [ -f "$REPO_DIR/.claude/context/state/recap.md" ] && pass "handoff mode writes recap.md" || fail "no recap.md"
  rm -f "$REPO_DIR/.claude/context/state/handoff.pending" "$REPO_DIR/.claude/context/state/recap.md"
fi

# --- context engine: ctxprune validate ---
CTXP=".claude/context/ctxprune.sh"
need_exec "$CTXP"
if [ -x "$REPO_DIR/$CTXP" ]; then
  run_expect "ctxprune validate clean fixture" 0 "$REPO_DIR/$CTXP" validate "$REPO_DIR/$FIX"
  # remove only the tool_result line for tu2 (leaving its tool_use orphaned).
  # NOTE: grep -v '"tu2"' would also delete the tool_use line (same substring),
  # producing a still-valid file — filter on the tool_result-specific key instead.
  broken="$(mktemp)"; grep -v '"tool_use_id":"tu2"' "$REPO_DIR/$FIX" > "$broken" || true
  run_expect "ctxprune validate broken fixture rejects" 1 "$REPO_DIR/$CTXP" validate "$broken"
  rm -f "$broken"
fi

# --- context engine: ctxprune prune ---
if [ -x "$REPO_DIR/$CTXP" ]; then
  out="$(mktemp)"
  "$REPO_DIR/$CTXP" prune "$REPO_DIR/$FIX" "$out" 2>/dev/null || true
  run_expect "pruned output validates" 0 "$REPO_DIR/$CTXP" validate "$out"
  # capsules: only the last assistant turn (tu2's) retained -> 1 signature remains
  sigs="$(jq -r '.message.content[]?|select(.type=="thinking")|.signature' "$out" 2>/dev/null | grep -c . || true)"
  [ "$sigs" = "1" ] && pass "prune drops prior-turn capsules (1 left)" || fail "prune capsules (got $sigs want 1)"
  # tu1 result stubbed
  stub="$(jq -r 'select(.message.content!=null)|.message.content[]?|select(.type=="tool_result" and .tool_use_id=="tu1")|.content' "$out" 2>/dev/null || true)"
  printf '%s' "$stub" | grep -q 'pruned: re-read' && pass "prune stubs superseded read of foo.sh" || fail "prune stub (got: $stub)"
  # golden-output regression
  if diff -q "$out" "$REPO_DIR/.claude/context/fixtures/sample_pruned.expected.jsonl" >/dev/null 2>&1; then
    pass "prune matches golden"
  else
    fail "prune drifted from golden"
  fi
  rm -f "$out"
fi

# --- context engine: ctxprune clone ---
if [ -x "$REPO_DIR/$CTXP" ]; then
  tmpproj="$(mktemp -d)"; sid="00000000-0000-0000-0000-000000000001"
  cp "$REPO_DIR/$FIX" "$tmpproj/$sid.jsonl"
  out="$(CTX_PROJECTS_DIR="$tmpproj" "$REPO_DIR/$CTXP" clone "$sid" 2>/dev/null || true)"
  printf '%s' "$out" | grep -q 'claude --resume' && pass "ctxprune clone prints resume cmd" || fail "ctxprune clone (got: $out)"
  newid="$(printf '%s' "$out" | grep -oE 'resume [0-9a-f-]+' | awk '{print $2}')"
  [ -n "$newid" ] && [ -f "$tmpproj/$newid.jsonl" ] && pass "ctxprune clone wrote new session file" || fail "ctxprune clone new file missing"
  rm -rf "$tmpproj"
fi

# --- context engine: ctxprune sidechain-last-line regression (FIX 1) ---
# A subagent sidechain assistant line landing last in the file must not be
# mistaken for the real last main-chain turn; the kept thinking capsule must
# be the main-chain one (MAINSIG), not the trailing sidechain's (SUBSIG).
if [ -x "$REPO_DIR/$CTXP" ]; then
  sc="$(mktemp)"
  {
    printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"hi"}]}}'
    printf '%s\n' '{"type":"assistant","uuid":"a2","message":{"role":"assistant","content":[{"type":"thinking","thinking":"main","signature":"MAINSIG"},{"type":"tool_use","id":"tu1","name":"Task","input":{"description":"spawn"}}]}}'
    printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu1","content":"dispatched"}]}}'
    printf '%s\n' '{"type":"assistant","uuid":"sub1","isSidechain":true,"message":{"role":"assistant","content":[{"type":"thinking","thinking":"sub","signature":"SUBSIG"}]}}'
  } > "$sc"
  scout="$(mktemp)"
  "$REPO_DIR/$CTXP" prune "$sc" "$scout" 2>/dev/null || true
  sig="$(jq -r '.message.content[]?|select(.type=="thinking")|.signature' "$scout" 2>/dev/null)"
  [ "$sig" = "MAINSIG" ] && pass "prune keeps main-chain last capsule, not trailing sidechain" || fail "prune sidechain regression (got sig='$sig' want MAINSIG)"
  run_expect "pruned sidechain-regression output validates" 0 "$REPO_DIR/$CTXP" validate "$scout"
  rm -f "$sc" "$scout"
fi

# --- context engine: ctxprune malformed JSONL guard (FIX 2) ---
# A trailing truncated JSON line must not crash validate/prune under
# set -euo pipefail; both must fail clean with exit 1, not a raw jq abort.
if [ -x "$REPO_DIR/$CTXP" ]; then
  mal="$(mktemp)"
  {
    printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"hi"}]}}'
    printf '%s' '{"type":"assistant"'
  } > "$mal"
  malout="$(mktemp)"
  run_expect "ctxprune validate malformed JSONL -> 1" 1 "$REPO_DIR/$CTXP" validate "$mal"
  run_expect "ctxprune prune malformed JSONL -> 1" 1 "$REPO_DIR/$CTXP" prune "$mal" "$malout"
  rm -f "$mal" "$malout"
fi

# --- context engine: claude-loop supervisor ---
LOOP=".claude/context/claude-loop.sh"
need_exec "$LOOP"
if [ -x "$REPO_DIR/$LOOP" ]; then
  cnt="$(mktemp)"; echo 0 > "$cnt"
  stub="$(mktemp)"; cat > "$stub" <<'STUB'
#!/usr/bin/env bash
n="$(cat "$CNTFILE")"; n=$((n+1)); echo "$n" > "$CNTFILE"
if [ "$n" = "1" ]; then : > "$HANDOFF"; fi   # first run requests handoff
exit 0
STUB
  chmod +x "$stub"
  HANDOFF="$REPO_DIR/.claude/context/state/handoff.pending" \
  CNTFILE="$cnt" CTX_CLAUDE_CMD="$stub" FLUSH_SETTLE_SECS="${FLUSH_SETTLE_SECS:-0}" "$REPO_DIR/$LOOP" >/dev/null 2>&1 || true
  runs="$(cat "$cnt")"
  [ "$runs" = "2" ] && pass "supervisor relaunches once on handoff (2 runs)" || fail "supervisor runs=$runs want 2"
  rm -f "$stub" "$cnt" "$REPO_DIR/.claude/context/state/handoff.pending"

  # FIX 1: on the no-handoff path, the supervisor must propagate the child's
  # exit code instead of always exiting 0.
  stub42="$(mktemp)"; cat > "$stub42" <<'STUB42'
#!/usr/bin/env bash
exit 42
STUB42
  chmod +x "$stub42"
  handoff42="$(mktemp -u)"
  run_expect "supervisor propagates child exit" 42 env CTX_CLAUDE_CMD="$stub42" HANDOFF="$handoff42" FLUSH_SETTLE_SECS=0 bash "$REPO_DIR/$LOOP"
  rm -f "$stub42" "$handoff42"
fi

printf '\nSUMMARY | PASS=%d FAIL=%d\n' "$pass_count" "$fail_count"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
