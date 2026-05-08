#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
REFRESH_SCRIPT="${AEROSPACE_SPACES_SCRIPT:-$PLUGIN_DIR/aerospace_spaces.sh}"
CACHE_ROOT="${AEROSPACE_SPACES_REFRESH_CACHE_DIR:-${TMPDIR:-/tmp}/sketchybar}"
STATE_DIR="$CACHE_ROOT/aerospace_spaces_refresh"
LOCK_DIR="$STATE_DIR/lock"
LOCK_PID_FILE="$LOCK_DIR/pid"
REQUEST_FILE="$STATE_DIR/request"
DEBOUNCE_SECONDS="${AEROSPACE_SPACES_REFRESH_DEBOUNCE:-0.08}"
STALE_LOCK_SECONDS="${AEROSPACE_SPACES_REFRESH_STALE_LOCK_SECONDS:-5}"

mkdir -p "$STATE_DIR"
printf '%s.%s\n' "$(/bin/date +%s 2>/dev/null || printf '0')" "$$" >"$REQUEST_FILE"

acquire_lock() {
  if /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  fi

  lock_pid="$(/bin/cat "$LOCK_PID_FILE" 2>/dev/null || true)"
  if [ -n "$lock_pid" ] && /bin/kill -0 "$lock_pid" 2>/dev/null; then
    return 1
  fi

  now="$(/bin/date +%s 2>/dev/null || printf '0')"
  lock_mtime="$(/usr/bin/stat -f %m "$LOCK_DIR" 2>/dev/null || printf '0')"
  lock_age=$((now - lock_mtime))
  if [ "$lock_age" -lt "$STALE_LOCK_SECONDS" ]; then
    return 1
  fi

  /bin/rm -f "$LOCK_PID_FILE" 2>/dev/null || true
  /bin/rmdir "$LOCK_DIR" 2>/dev/null || true
  /bin/mkdir "$LOCK_DIR" 2>/dev/null
}

if ! acquire_lock; then
  exit 0
fi

release_lock() {
  /bin/rm -f "$LOCK_PID_FILE" 2>/dev/null || true
  /bin/rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap release_lock EXIT INT TERM

printf '%s\n' "$$" >"$LOCK_PID_FILE" 2>/dev/null || true
last_refreshed_request=""

while :; do
  before="$(/bin/cat "$REQUEST_FILE" 2>/dev/null || true)"
  /bin/sleep "$DEBOUNCE_SECONDS"
  latest="$(/bin/cat "$REQUEST_FILE" 2>/dev/null || true)"

  if [ "$latest" != "$before" ]; then
    continue
  fi

  "$REFRESH_SCRIPT" >/dev/null 2>&1 || true
  last_refreshed_request="$latest"

  after="$(/bin/cat "$REQUEST_FILE" 2>/dev/null || true)"
  if [ "$after" = "$last_refreshed_request" ]; then
    release_lock
    trap - EXIT INT TERM

    final="$(/bin/cat "$REQUEST_FILE" 2>/dev/null || true)"
    if [ "$final" != "$last_refreshed_request" ]; then
      exec "$0"
    fi
    exit 0
  fi
done
