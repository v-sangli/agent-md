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

need_file ".claude/ENV.md"
need_file ".claude/policy/AGENT_RULES.md"
need_file ".claude/policy/OPERATING_SPEC.md"
need_file ".claude/settings.json"
need_file ".claude/hooks/session_start.sh"
need_file ".claude/hooks/session_end.sh"
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

# Retired with the 3.0 rollback and deleted 2026-08-12. Absence is asserted so
# the blocking model cannot creep back in unnoticed.
need_absent ".claude/access.conf"
need_absent ".claude/harness"
need_absent ".claude/hooks/access_guard.sh"
need_absent ".claude/hooks/pre_tool_use_guard.sh"
need_absent ".claude/hooks/pre_tool_use_bash_guard.sh"
need_absent ".claude/hooks/post_tool_use_privilege_guard.sh"

need_exec ".claude/hooks/session_start.sh"
need_exec ".claude/hooks/session_end.sh"
need_exec ".claude/skills/tmux-control/scripts/tmux_control.sh"

# Portability: this harness is a general template. Only .claude/ENV.md may name
# one machine's paths or environments — everything else must resolve through
# $CLAUDE_PROJECT_DIR or a relative path. Vendored plugins are upstream content
# and settings.local.json is machine-local, so both are out of scope.
env_leaks="$(rg -l --no-messages '/home/[a-zA-Z]|/Users/[a-zA-Z]' "$REPO_DIR/.claude" \
  -g '!**/skills/dx/**' -g '!**/skills/superpowers/**' \
  -g '!**/ENV.md' -g '!**/settings.local.json' || true)"
if [ -z "$env_leaks" ]; then
  pass "harness is machine-portable: absolute home paths confined to ENV.md"
else
  fail "harness is machine-portable: absolute home paths confined to ENV.md"
  printf '%s\n' "$env_leaks" | sed 's|^|        leak: |'
fi

if jq -e '
  (.hooks.SessionStart != null) and
  (.hooks.PreToolUse == null) and
  (.hooks.PostToolUse == null) and
  (.hooks.PostToolUseFailure == null) and
  ((.permissions.allow // []) | index("Bash") != null) and
  ((.permissions.ask // []) | index("Bash(sudo:*)") != null) and
  ([.. | strings | select(test("^/home/|^/Users/"))] | length == 0)
' "$REPO_DIR/.claude/settings.json" >/dev/null; then
  pass "settings.json is advisory: SessionStart/SessionEnd only, broad allow, no absolute paths"
else
  fail "settings.json is advisory: SessionStart/SessionEnd only, broad allow, no absolute paths"
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
  "bin/activate" \
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
  "## Conventions" \
  "not a gate" \
  "tmux-control" \
  ".claude/ENV.md" \
  "PYTHONPATH=."; do
  rg -Fq "$required" "$REPO_DIR/.claude/policy/AGENT_RULES.md" || policy_ok=0
done
for required in \
  "Version: 3.0" \
  "canonical rule source" \
  "The 3.0 Rollback" \
  "tmux-control" \
  ".claude/ENV.md"; do
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

tc="$REPO_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh"
tc_env="CLAUDE_CODE_SESSION_ID=verify-$$"
run_expect "tmux-control root request: user-owned session + sudo -i, never sudo tmux" 0 bash -lc "$tc_env '$tc' root-request --session root-verify --cwd '$REPO_DIR' --command 'true' >/tmp/verify_root_request.out && rg -q 'tmux attach -t root-verify' /tmp/verify_root_request.out && ! rg -q 'sudo tmux|paste the output|in-session ! sudo.*alternative' /tmp/verify_root_request.out && tmux has-session -t root-verify && tmux capture-pane -p -t root-verify | rg -q 'sudo -i'; rc=\$?; $tc_env '$tc' stop --session root-verify >/dev/null; exit \$rc"
run_expect "tmux-control cleanup stops only own non-kept sessions" 0 bash -lc "$tc_env '$tc' start --session verify-own >/dev/null && $tc_env '$tc' start --session verify-kept --keep >/dev/null && CLAUDE_CODE_SESSION_ID=verify-other-$$ '$tc' start --session verify-other >/dev/null && $tc_env '$tc' cleanup >/dev/null; ! tmux has-session -t verify-own 2>/dev/null && tmux has-session -t verify-kept && tmux has-session -t verify-other; rc=\$?; for s in verify-own verify-kept verify-other; do $tc_env '$tc' stop --session \$s >/dev/null; done; exit \$rc"

printf '\nSUMMARY | PASS=%d FAIL=%d\n' "$pass_count" "$fail_count"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
