#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-$(pwd)}"
REPO_DIR="$(cd "$REPO_DIR" && pwd)"

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
need_absent "reference"
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
  ((.permissions.allow // []) | index("Bash(.claude/harness/run.sh:*)") != null) and
  ((.permissions.ask // []) | index("Bash(rm -rf:*)") | not) and
  ((.permissions.deny // []) | index("Edit(.claude/**)") | not) and
  ((.permissions.deny // []) | index("Write(.claude/**)") | not) and
  ([.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command] | index("bash .claude/hooks/access_guard.sh") | not)
' "$REPO_DIR/.claude/settings.json" >/dev/null; then
  pass "settings.json routes Bash mutation through harness, not access-guard allow"
else
  fail "settings.json routes Bash mutation through harness, not access-guard allow"
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
  "source ~/miniconda3/bin/activate dexpolicy" \
  "python -V" \
  "which python" \
  "PYTHONPATH=."; do
  rg -Fq "$required" "$REPO_DIR/.claude/ENV.md" || env_ok=0
done
for required in \
  'Read `.claude/ENV.md`' \
  "source ~/miniconda3/bin/activate dexpolicy" \
  "PYTHONPATH=."; do
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
  "Version: 2.0" \
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
for key in "STATE REINJECTION" "SESSION_ID:" "RULE SNAPSHOT:"; do
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

run_expect "access classifier asks for .claude write" 0 bash -lc '
repo="$1"
jq -n --arg path ".claude/settings.json" "{tool_name:\"Write\",tool_input:{file_path:\$path}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_claude.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_claude.out >/dev/null &&
  rg -q "CRITICAL.*\\.claude" /tmp/verify_access_claude.out
' _ "$REPO_DIR"
run_expect "access classifier marks workspace rm-rf as allow" 0 bash -lc '
repo="$1"
jq -n --arg cmd "rm -rf build/tmp && rm -rf .cache/foo" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_workspace.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"allow\"" /tmp/verify_access_workspace.out >/dev/null
' _ "$REPO_DIR"
run_expect "access classifier asks for mashed external rm-rf" 0 bash -lc '
repo="$1"
jq -n --arg cmd "mkdir -p build && rm -rf build/tmp && rm -rf /opt/foo" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_external.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_external.out >/dev/null &&
  rg -q "/opt/foo" /tmp/verify_access_external.out
' _ "$REPO_DIR"
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
repo="$1"
jq -n --arg path "/opt/foo" "{tool_name:\"Write\",tool_input:{file_path:\$path}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_write_external.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_write_external.out >/dev/null &&
  rg -q "/opt/foo" /tmp/verify_access_write_external.out
' _ "$REPO_DIR"
run_expect "access classifier asks for dynamic rm target" 0 bash -lc '
repo="$1"
jq -n --arg cmd "rm -rf \"\$TARGET\"" "{tool_name:\"Bash\",tool_input:{command:\$cmd}}" |
  CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/access_guard.sh" >/tmp/verify_access_dynamic.out &&
  jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" /tmp/verify_access_dynamic.out >/dev/null &&
  rg -q "dynamic|unresolved" /tmp/verify_access_dynamic.out
' _ "$REPO_DIR"

run_expect "pre_tool_use_bash_guard blocks direct workspace rm-rf and routes to harness" 2 bash -lc "set +e; printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf build/tmp\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' 2>/tmp/verify_direct_rm.err; rc=\$?; set -e; rg -q '.claude/harness/run.sh' /tmp/verify_direct_rm.err; exit \$rc"
run_expect "pre_tool_use_bash_guard blocks direct sed in-place and routes to harness" 2 bash -lc "set +e; printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -i s/x/y/ file.txt\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' 2>/tmp/verify_direct_sed_i.err; rc=\$?; set -e; rg -q '.claude/harness/run.sh' /tmp/verify_direct_sed_i.err; exit \$rc"
run_expect "pre_tool_use_bash_guard blocks direct redirection and routes to harness" 2 bash -lc "set +e; printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat input.txt > out.txt\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' 2>/tmp/verify_direct_redirect.err; rc=\$?; set -e; rg -q '.claude/harness/run.sh' /tmp/verify_direct_redirect.err; exit \$rc"
run_expect "harness runner executes workspace rm-rf" 0 bash -lc "cd '$REPO_DIR' && rm -rf .verify-harness && mkdir -p .verify-harness/child && .claude/harness/run.sh -- 'rm -rf .verify-harness/child' && test ! -e .verify-harness/child && rm -rf .verify-harness"
run_expect "harness runner executes safe /tmp cleanup" 0 bash -lc "mkdir -p /tmp/claude-harness-verify && '$REPO_DIR/.claude/harness/run.sh' -- 'rm -rf /tmp/claude-harness-verify' && test ! -e /tmp/claude-harness-verify"
run_expect "harness runner asks for external delete without running" 3 bash -lc "cd '$REPO_DIR'; set +e; .claude/harness/run.sh -- 'rm -rf /opt/claude-harness-test' 2>/tmp/verify_harness_external.err; rc=\$?; set -e; rg -q 'Approval required' /tmp/verify_harness_external.err; exit \$rc"
run_expect "harness runner treats critical delete as non-running request" 4 bash -lc "cd '$REPO_DIR'; set +e; .claude/harness/run.sh -- 'rm -rf /tmp' 2>/tmp/verify_harness_critical.err; rc=\$?; set -e; rg -q 'Critical approval required' /tmp/verify_harness_critical.err; exit \$rc"
run_expect "harness runner asks for dynamic target without running" 3 bash -lc "cd '$REPO_DIR'; set +e; .claude/harness/run.sh -- 'rm -rf \"\$TARGET\"' 2>/tmp/verify_harness_dynamic.err; rc=\$?; set -e; rg -q 'dynamic|unresolved' /tmp/verify_harness_dynamic.err; exit \$rc"

run_expect "pre_tool_use_bash_guard blocks pip install" 2 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pip install requests\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard blocks compound install after rm-rf" 2 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf build && pip install requests\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard redirects sudo" 2 bash -lc "set +e; printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sudo true\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh' 2>/tmp/verify_sudo_redirect.err; rc=\$?; set -e; rg -q 'root-request' /tmp/verify_sudo_redirect.err; exit \$rc"
run_expect "pre_tool_use_bash_guard blocks direct pytest" 2 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pytest -q\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard allows tmux-control helper" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\".claude/skills/tmux-control/scripts/tmux_control.sh send --target smoke::run --command '\\''pytest -q'\\''\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "pre_tool_use_bash_guard allows root-request with sudo argument" 0 bash -lc "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\".claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-verify --cwd . --command '\\''sudo true'\\''\"}}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/pre_tool_use_bash_guard.sh'"
run_expect "tmux-control root request only offers root tmux" 0 bash -lc "cd '$REPO_DIR' && .claude/skills/tmux-control/scripts/tmux_control.sh root-request --session root-verify --cwd '$REPO_DIR' --command 'sudo true' >/tmp/verify_root_request.out && rg -q 'approve a visible root tmux session' /tmp/verify_root_request.out && rg -q 'real terminal' /tmp/verify_root_request.out && ! rg -q 'Option 1|paste the output|in-session ! sudo.*alternative' /tmp/verify_root_request.out"
run_expect "post_tool_use_privilege_guard injects root guidance" 0 bash -lc "printf '{\"hook_event_name\":\"PostToolUseFailure\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"dmesg | tail\"},\"error\":\"dmesg: read kernel buffer failed: Operation not permitted\"}' | CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/post_tool_use_privilege_guard.sh' >/tmp/verify_privilege_hook.out && jq -e . /tmp/verify_privilege_hook.out >/dev/null && rg -q 'root-request' /tmp/verify_privilege_hook.out && rg -q 'true equivalent' /tmp/verify_privilege_hook.out && rg -q 'Do not suggest in-session' /tmp/verify_privilege_hook.out"

printf '\nSUMMARY | PASS=%d FAIL=%d\n' "$pass_count" "$fail_count"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
