#!/usr/bin/env bash

set -u

AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
RESET_SCRIPT="$HOME/.config/aerospace/reset-apps-to-default-workspaces.sh"
SPACE_PLUGIN="$HOME/.config/sketchybar/plugins/aerospace_spaces.sh"
RESTORE_DELAY="${AEROSPACE_STARTUP_RESTORE_DELAY:-2}"
MAIN_MONITOR_NAME="${AEROSPACE_MAIN_MONITOR_NAME:-PHL 279C9}"
SIDE_MONITOR_NAME="${AEROSPACE_SIDE_MONITOR_NAME:-24V5C2}"

wait_for_aerospace() {
    local attempt=0
    local monitors

    while [ "$attempt" -lt 20 ]; do
        monitors="$("$AEROSPACE_BIN" list-monitors --format '%{monitor-name}' 2>/dev/null || true)"
        if [ -n "$monitors" ] &&
            /usr/bin/grep -Fxq "$MAIN_MONITOR_NAME" <<<"$monitors" &&
            /usr/bin/grep -Fxq "$SIDE_MONITOR_NAME" <<<"$monitors"; then
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 0.5
    done

    [ -n "$monitors" ]
}

sleep "$RESTORE_DELAY"
wait_for_aerospace || exit 0

# SketchyBar may start before AeroSpace has stable display metadata. Reload once
# after AeroSpace is ready so workspace items bind to the current monitor IDs.
"$SKETCHYBAR_BIN" --reload >/dev/null 2>&1 || true
sleep 0.5

if [ -x "$RESET_SCRIPT" ]; then
    "$RESET_SCRIPT" >/dev/null 2>&1 || true
fi

if [ -x "$SPACE_PLUGIN" ]; then
    "$SPACE_PLUGIN" >/dev/null 2>&1 || true
fi
