#!/usr/bin/env bash

set -u

# Runs once from AeroSpace's after-startup-command. Its job is to wait until the
# display layout has settled, then put windows back where they belong and let
# SketchyBar rebind its items to the current monitor ids.
#
# The waiting used to be "poll until the two displays named in this file are
# both connected", with a ten-second ceiling each for AeroSpace and for
# Hammerspoon. On a Mac without those displays - a laptop on its own, anyone
# else's desk - neither condition could ever become true, so every login paid
# the full twenty seconds and then continued anyway. What actually needs
# waiting for is the display list settling down, which is something any machine
# can reach.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=lib/layout.sh
source "$SCRIPT_DIR/lib/layout.sh"

AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"
RESET_SCRIPT="${AEROSPACE_RESET_SCRIPT:-$SCRIPT_DIR/reset-apps-to-default-workspaces.sh}"
SPACE_PLUGIN="${AEROSPACE_SPACES_PLUGIN:-$HOME/.config/sketchybar/plugins/aerospace_spaces.sh}"
RESTORE_DELAY="${AEROSPACE_STARTUP_RESTORE_DELAY:-2}"
SCREEN_WAIT_ATTEMPTS="${AEROSPACE_SCREEN_WAIT_ATTEMPTS:-8}"
SCREEN_WAIT_INTERVAL="${AEROSPACE_SCREEN_WAIT_INTERVAL:-0.25}"

# Hammerspoon publishes screen metadata slightly after AeroSpace does, and
# SketchyBar item placement reads it. Any answer is enough - which screens are
# there is the display list's business, already settled above.
wait_for_screen_metadata() {
    local attempt=0
    local screens

    [ -x "$HS_BIN" ] || return 0

    while [ "$attempt" -lt "$SCREEN_WAIT_ATTEMPTS" ]; do
        screens="$("$HS_BIN" -c 'for _, screen in ipairs(hs.screen.allScreens()) do print(screen:name()) end' 2>/dev/null || true)"
        if [ -n "$screens" ]; then
            return 0
        fi

        attempt=$((attempt + 1))
        sleep "$SCREEN_WAIT_INTERVAL"
    done

    return 0
}

sleep "$RESTORE_DELAY"
aerospace_layout_wait_for_monitors || exit 0
wait_for_screen_metadata

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
