#!/usr/bin/env bash
# Sourced helper. externalized_since <epoch_ts> <path...> -> exit 0 if any
# path was modified at or after epoch_ts (i.e. reasoning was written down).
externalized_since() {
  local ts="$1"; shift
  local p m
  for p in "$@"; do
    [ -e "$p" ] || continue
    m="$(stat -c %Y "$p" 2>/dev/null || echo 0)"
    [ "$m" -ge "$ts" ] && return 0
  done
  return 1
}
