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

need_absent ".claude/ENV.md"
# ENV.md was replaced by the agent-docs store (ADR 0012). Only the ADRs (history), the
# branch-only spec, plan and spikes, and this verifier (which asserts its absence) may
# still name it. Other worktrees of the repo are their own checkouts and are skipped.
env_refs="$(rg -l --hidden --no-messages 'ENV[.]md' "$REPO_DIR" \
  -g '!.git' -g '!docs/adr/**' -g '!docs/superpowers/**' -g '!spikes/**' \
  -g '!.claude/worktrees/**' -g '!.claude/verify_setup.sh' || true)"
if [ -z "$env_refs" ]; then
  pass "no file names the removed ENV.md"
else
  fail "no file names the removed ENV.md"
  printf '%s\n' "$env_refs" | sed 's|^|        names it: |'
fi
need_file ".claude/policy/OPERATING_SPEC.md"
need_file "docs/adr/0001-advisory-enforcement.md"
need_file ".claude/settings.json"
need_file ".claude/hooks/session_start.sh"
need_file ".claude/skills/dev-flow/SKILL.md"
need_file ".claude/skills/dev-flow/references/interface-sketch.md"
need_file ".claude/skills/dev-flow/references/adr-template.md"
need_file ".claude/skills/tmux-control/SKILL.md"
need_file ".claude/skills/tmux-control/references/commands.md"
need_file ".claude/skills/tmux-control/references/sudo.md"
need_file ".claude/skills/tmux-control/references/validation.md"
need_file ".claude/skills/tmux-control/scripts/tmux_control.sh"
need_file ".claude/skills/superpowers/.claude-plugin/plugin.json"
need_file ".claude/skills/superpowers/CLAUDE.md"
need_file ".claude/skills/superpowers/AGENTS.md"
need_file ".claude/skills/superpowers/skills/using-superpowers/SKILL.md"
need_file ".claude/skills/superpowers/skills/brainstorming/SKILL.md"
need_file ".claude/skills/shipping-and-launch/SKILL.md"
need_file ".claude/skills/agent-docs/SKILL.md"
need_file ".claude/skills/agent-docs/scripts/agent_docs.sh"
need_file ".claude-workflow/install_prov.sh"

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

# Folded into CLAUDE.md (Conventions) on 2026-11-13. It was never auto-loaded,
# so its rules held only when the agent went and read it. Absence is asserted
# so a second rule source cannot creep back in.
need_absent ".claude/policy/AGENT_RULES.md"

need_exec ".claude/hooks/session_start.sh"
need_exec ".claude/hooks/session_end.sh"
need_exec ".claude/skills/tmux-control/scripts/tmux_control.sh"
need_exec ".claude/skills/agent-docs/scripts/agent_docs.sh"
need_exec ".claude-workflow/install_prov.sh"

# Portability: this harness is a general template. No file in it names one machine's
# paths: everything resolves through $CLAUDE_PROJECT_DIR, ~ or a relative path, and
# workspace facts live in the user-scoped store ~/.agent-docs/. Vendored plugins are
# upstream content and settings.local.json is machine-local, so both are out of scope.
# CLAUDE.md is part of the template and is scanned too; one machine's rules live in
# CLAUDE.local.md, which is not.
env_leaks="$(rg -l --no-messages '/home/[a-zA-Z]|/Users/[a-zA-Z]' "$REPO_DIR/.claude" "$REPO_DIR/CLAUDE.md" \
  -g '!**/skills/superpowers/**' \
  -g '!**/settings.local.json' || true)"
if [ -z "$env_leaks" ]; then
  pass "harness is machine-portable: no absolute home paths"
else
  fail "harness is machine-portable: no absolute home paths"
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
  printf '%s' "$standalone_names" | rg -qx 'dev-flow' &&
  printf '%s' "$standalone_names" | rg -qx 'agent-docs' &&
  [ "$plugin_skill_count" -ge 13 ] &&
  printf '%s' "$plugin_skill_names" | rg -qx 'superpowers:using-superpowers' &&
  [ "$skill_bad" -eq 0 ]; then
  pass "standalone skills and project-scope plugins have Claude-compatible metadata"
else
  fail "standalone skills and project-scope plugins have Claude-compatible metadata"
fi

claude_ok=1
for required in \
  "## Code stance" \
  "### When a test is red" \
  "## Isolation and gates" \
  "## Karpathy guidelines" \
  "**Think before coding.**" \
  "**Scope of a change.**"; do
  rg -Fq "$required" "$REPO_DIR/CLAUDE.md" || claude_ok=0
done
if [ "$claude_ok" -eq 1 ]; then
  pass "CLAUDE.md contains the code stance and the kept Karpathy guidance"
else
  fail "CLAUDE.md contains the code stance and the kept Karpathy guidance"
fi

# CLAUDE.md is loaded into every session and every subagent; the cap keeps its growth
# deliberate.
claude_lines="$(wc -l <"$REPO_DIR/CLAUDE.md")"
if [ "$claude_lines" -lt 300 ]; then
  pass "CLAUDE.md is under 300 lines ($claude_lines)"
else
  fail "CLAUDE.md is under 300 lines ($claude_lines)"
fi

wiring_ok=1
rg -qx '@~/\.agent-docs/INDEX\.md' "$REPO_DIR/CLAUDE.md" || wiring_ok=0
jq -e '.permissions.additionalDirectories | index("~/.agent-docs") != null' \
  "$REPO_DIR/.claude/settings.json" >/dev/null 2>&1 || wiring_ok=0
for required in "OPERATING_SPEC.md" "agent-docs"; do
  rg -Fq "$required" "$REPO_DIR/CLAUDE.md" || wiring_ok=0
done
if [ "$wiring_ok" -eq 1 ]; then
  pass "agent-docs wiring: CLAUDE.md imports the index, settings add the store"
else
  fail "agent-docs wiring: CLAUDE.md imports the index, settings add the store"
fi

policy_ok=1
for required in \
  "## Conventions" \
  "not a gate" \
  "tmux-control" \
  "~/.agent-docs/" \
  "PYTHONPATH=." \
  "Five things need the user's word" \
  "**A release.**"; do
  rg -Fq "$required" "$REPO_DIR/CLAUDE.md" || policy_ok=0
done
rg -Fq "CI creates the git tag" "$REPO_DIR/.claude/skills/dev-flow/SKILL.md" && policy_ok=0
rg -Fq "shipping-and-launch" "$REPO_DIR/.claude/skills/dev-flow/SKILL.md" || policy_ok=0
for required in \
  "Version: " \
  "canonical rule source" \
  "Where Rules Live" \
  "docs/adr/" \
  "dev-flow" \
  "tmux-control" \
  "~/.agent-docs/"; do
  rg -Fq "$required" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md" || policy_ok=0
done
if rg -Fq ".claude-log" "$REPO_DIR/CLAUDE.md" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md" ||
  rg -Fq ".claude-tools" "$REPO_DIR/CLAUDE.md" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md" ||
  rg -Fq "spec_hashes.json" "$REPO_DIR/CLAUDE.md" "$REPO_DIR/.claude/policy/OPERATING_SPEC.md"; then
  policy_ok=0
fi
if [ "$policy_ok" -eq 1 ]; then
  pass "policy docs are restored for the lean harness"
else
  fail "policy docs are restored for the lean harness"
fi

ship_ok=1
ship_md="$REPO_DIR/.claude/skills/shipping-and-launch/SKILL.md"
if [ -f "$ship_md" ]; then
  for required in "## The release gate" "## Release targets" "@release" "8c99fa3"; do
    rg -Fq "$required" "$ship_md" || ship_ok=0
  done
  rg -q 'git revert .*&& *git push' "$ship_md" && ship_ok=0
  rg -q 'git push[^`]*(--force|-f |main)' "$ship_md" && ship_ok=0
else
  ship_ok=0
fi
if [ "$ship_ok" -eq 1 ]; then
  pass "shipping-and-launch: release gate, targets, no push to main or force-push"
else
  fail "shipping-and-launch: release gate, targets, no push to main or force-push"
fi

ss_out="$(printf '{"session_id":"verify"}' | CLAUDE_PROJECT_DIR="$REPO_DIR" bash "$REPO_DIR/.claude/hooks/session_start.sh")"
for key in "STATE REINJECTION" "SESSION_ID:" "RULE SOURCES:" "POINTERS:" "AGENT DOCS:" "agent-docs: " '`sudo -i`' '`sudo tmux`'; do
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

# prov status at session start (ADR 0011): from the pointer file install_prov.sh writes.
printf 'home = "/opt/prov"\nref = "prov-v9.9.9"\ncommit = "abcdef0123456789"\nbin = "/opt/bin"\nskills = "prov prov-journal prov-plot"\nusage = "/opt/prov/docs/usage.md"\n' >/tmp/verify_prov_pointer.toml
run_expect "session_start reports the installed prov from its pointer file" 0 bash -c "printf '{}' | PROV_POINTER=/tmp/verify_prov_pointer.toml CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/session_start.sh' | rg -q '^PROV: prov-v9.9.9 \(abcdef0\) at /opt/prov$'"
run_expect "session_start says how to install prov when there is no pointer file" 0 bash -c "printf '{}' | PROV_POINTER=/tmp/verify_prov_none.toml CLAUDE_PROJECT_DIR='$REPO_DIR' bash '$REPO_DIR/.claude/hooks/session_start.sh' | rg -q 'install_prov.sh <release tag>'"

# The workspace journal at session start (ADR 0015): named inside a prov project, or how to create it.
rm -rf /tmp/verify_prov_ws /tmp/verify_prov_ws_bare && mkdir -p /tmp/verify_prov_ws/journal /tmp/verify_prov_ws_bare
printf 'project = "ws"\n' | tee /tmp/verify_prov_ws/prov.toml >/tmp/verify_prov_ws_bare/prov.toml
printf '# Now\n' >/tmp/verify_prov_ws/journal/NOW.md
run_expect "session_start names the workspace journal as the home for docs" 0 bash -c "printf '{}' | CLAUDE_PROJECT_DIR=/tmp/verify_prov_ws bash '$REPO_DIR/.claude/hooks/session_start.sh' 2>/dev/null | rg -q '^- Journal: /tmp/verify_prov_ws/journal, the default home for docs'"
run_expect "session_start says how to create the journal when a prov project has none" 0 bash -c "printf '{}' | CLAUDE_PROJECT_DIR=/tmp/verify_prov_ws_bare bash '$REPO_DIR/.claude/hooks/session_start.sh' 2>/dev/null | rg -q 'No journal yet: run prov-journal init in /tmp/verify_prov_ws_bare'"

tc="$REPO_DIR/.claude/skills/tmux-control/scripts/tmux_control.sh"
tc_env="CLAUDE_CODE_SESSION_ID=verify-$$"
run_expect "tmux-control root request: user-owned session + sudo -i, never sudo tmux" 0 bash -lc "$tc_env '$tc' root-request --session root-verify --cwd '$REPO_DIR' --command 'true' >/tmp/verify_root_request.out && rg -q 'tmux attach -t root-verify' /tmp/verify_root_request.out && ! rg -q 'sudo tmux|paste the output|in-session ! sudo.*alternative' /tmp/verify_root_request.out && tmux has-session -t root-verify && tmux capture-pane -p -J -t root-verify | rg -q 'sudo -i'; rc=\$?; $tc_env '$tc' stop --session root-verify >/dev/null; exit \$rc"
run_expect "tmux-control wait matches a line wider than the pane" 0 bash -lc "$tc_env '$tc' start --session verify-wrap >/dev/null && $tc_env '$tc' send --target verify-wrap::run --command 'printf %0120d%s\\\\n 0 WRAPEND' >/dev/null && $tc_env '$tc' wait --target verify-wrap::run --pattern '0{100}WRAPEND' --timeout 5 --interval 1 >/dev/null; rc=\$?; $tc_env '$tc' stop --session verify-wrap >/dev/null; exit \$rc"
run_expect "tmux-control start: the first command's last output line survives the pane layout" 0 bash -lc "$tc_env '$tc' start --session verify-ready >/dev/null && $tc_env '$tc' send --target verify-ready::run --command 'echo READY' >/dev/null && $tc_env '$tc' wait --target verify-ready::run --pattern '^READY\$' --timeout 10 --interval 1 >/dev/null; rc=\$?; $tc_env '$tc' stop --session verify-ready >/dev/null; exit \$rc"
run_expect "tmux-control cleanup stops only own non-kept sessions" 0 bash -lc "$tc_env '$tc' start --session verify-own >/dev/null && $tc_env '$tc' start --session verify-kept --keep >/dev/null && CLAUDE_CODE_SESSION_ID=verify-other-$$ '$tc' start --session verify-other >/dev/null && $tc_env '$tc' cleanup >/dev/null; ! tmux has-session -t verify-own 2>/dev/null && tmux has-session -t verify-kept && tmux has-session -t verify-other; rc=\$?; for s in verify-own verify-kept verify-other; do $tc_env '$tc' stop --session \$s >/dev/null; done; exit \$rc"
run_expect "install_prov.sh without a ref prints its usage" 2 bash "$REPO_DIR/.claude-workflow/install_prov.sh"

# agent-docs: the store script against its fixtures.
ad="$REPO_DIR/.claude/skills/agent-docs/scripts/agent_docs.sh"
adf="$REPO_DIR/.claude/skills/agent-docs/tests/fixtures"

expect_agent_docs() { # LABEL EXIT PATTERN ROOT COMMAND
  local rc
  set +e
  bash "$ad" --root "$4" "$5" >/tmp/verify_agent_docs.out 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq "$2" ] && rg -Fq -- "$3" /tmp/verify_agent_docs.out; then
    pass "agent-docs: $1 (exit=$rc)"
  else
    fail "agent-docs: $1 (expected exit=$2 and '$3', got exit=$rc)"
    sed 's/^/  output: /' /tmp/verify_agent_docs.out
  fi
}

expect_agent_docs "valid store passes check" 0 "agent-docs: OK (4 docs)" "$adf/good" check
expect_agent_docs "doc without frontmatter" 1 "doc.md: no frontmatter" "$adf/no-frontmatter" check
expect_agent_docs "extra frontmatter key" 1 "doc.md: unknown or extra frontmatter key" "$adf/extra-key" check
expect_agent_docs "wrong first frontmatter key" 1 "doc.md: unknown or extra frontmatter key" "$adf/wrong-key" check
expect_agent_docs "empty description" 1 "doc.md: empty description" "$adf/empty-description" check
expect_agent_docs "wrapped description" 1 "doc.md: description not on one line" "$adf/multiline-description" check
expect_agent_docs "@ in a description" 1 "doc.md: description starts a word with @" "$adf/at-description" check
expect_agent_docs "stale index" 1 "INDEX.md: index stale" "$adf/stale-index" check
expect_agent_docs "missing root" 1 "does-not-exist: missing root" "$adf/does-not-exist" check

ad_tmp="$(mktemp -d)"
cp -R "$adf/good" "$ad_tmp/good"
rm "$ad_tmp/good/INDEX.md"
expect_agent_docs "missing index" 1 "INDEX.md: index missing" "$ad_tmp/good" check
expect_agent_docs "index on a valid store" 0 "agent-docs: OK (4 docs)" "$ad_tmp/good" index
if cmp -s "$adf/good/INDEX.md" "$ad_tmp/good/INDEX.md"; then
  pass "agent-docs: index reproduces the golden INDEX.md"
else
  fail "agent-docs: index reproduces the golden INDEX.md"
  diff "$adf/good/INDEX.md" "$ad_tmp/good/INDEX.md" | sed 's/^/  diff: /' || true
fi
cp -R "$adf/extra-key" "$ad_tmp/extra-key"
expect_agent_docs "index refuses an invalid store" 1 "unknown or extra frontmatter key" "$ad_tmp/extra-key" index
if cmp -s "$adf/extra-key/INDEX.md" "$ad_tmp/extra-key/INDEX.md"; then
  pass "agent-docs: a refused index leaves INDEX.md unchanged"
else
  fail "agent-docs: a refused index leaves INDEX.md unchanged"
fi
rm -rf "$ad_tmp"

printf '\nSUMMARY | PASS=%d FAIL=%d\n' "$pass_count" "$fail_count"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
