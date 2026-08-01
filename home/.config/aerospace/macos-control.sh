#!/usr/bin/env bash
set -euo pipefail

# Mission Control and App Exposé for `Ctrl + Up` / `Ctrl + Down`, over whichever
# route the machine in front of us actually has.
#
# This file used to be a single osascript line aimed at BetterTouchTool. That
# was fine while BTT was installed by the `all` profile. BTT is free for 45 days
# and paid after that, so it moved to `extras`, and on a default install the
# osascript now talks to an app that is not there. AeroSpace runs these bindings
# through `exec-and-forget`, which reads neither stdout nor stderr, so the
# failure had no symptom at all: two keys README.md and docs/shortcuts.md
# advertise did nothing, quietly, forever.
#
# Routes, tried best first:
#
#   bettertouchtool      Only when BTT is already running. It is the most
#                        faithful route - the same two predefined actions the
#                        tracked gesture preset binds to 3/4-finger swipes in
#                        home/.config/bettertouchtool/aerospace-gestures.sh.
#                        Running, not merely installed: `tell application
#                        "BetterTouchTool"` *launches* BTT, and
#                        bootstrap/install/bettertouchtool.sh deliberately does
#                        not start it, so an AppleScript here would undo that
#                        decision on every keypress.
#   hammerspoon          hs.spaces.toggleMissionControl / toggleAppExpose, which
#                        post the same CoreDock notification the Dock posts for
#                        a trackpad swipe. Hammerspoon is in the default
#                        `desktop` profile, so this is the route almost everyone
#                        lands on, and it is the only one that can do App Exposé
#                        without BTT.
#   mission-control-app  `open -a` on Mission Control.app. Mission Control only:
#                        macOS ships no App Exposé bundle to open.
#
# Deliberately not a route: osascript sending `key code 126 using control down`.
# Ctrl+Up and Ctrl+Down are the very chords AeroSpace binds to this script, and
# a synthesised chord re-enters the same system hotkey layer, so the binding
# fires this script again. It would also depend on the stock macOS Mission
# Control shortcuts still being enabled, while docs/troubleshooting.md tells
# people to switch the neighbouring ones off.
#
# Usage:
#   macos-control.sh mission-control|app-expose    do it
#   macos-control.sh --probe mission-control       name the route, run nothing
#
# Exit codes: 64 unusable arguments, 69 no route available on this machine.

action=""
probe_only=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --probe)
            probe_only=1
            ;;
        mission-control|app-expose)
            [ -z "$action" ] || exit 64
            action="$1"
            ;;
        *)
            exit 64
            ;;
    esac
    shift
done

[ -n "$action" ] || exit 64

# Resolves a program to a runnable absolute path, or prints nothing. Same shape
# as SketchyBar's lib/runtime.sh helper, kept local rather than sourced because
# this script has to work on a Mac that installed AeroSpace and nothing else.
#
# An override naming a path that is not there is still an answer: the caller
# asked for that path, and the emptiness is what tells the route to stand down.
macos_control_bin() {
    local override="${1:-}"
    local name="${2:-}"
    local candidate found

    if [ -n "$override" ]; then
        case "$override" in
            */*)
                [ -x "$override" ] && printf '%s\n' "$override"
                return 0
                ;;
            *)
                name="$override"
                ;;
        esac
    fi

    [ -n "$name" ] || return 0

    found="$(command -v "$name" 2>/dev/null || true)"
    if [ -n "$found" ] && [ -x "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi

    for candidate in "/opt/homebrew/bin/$name" "/usr/local/bin/$name"; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
}

# Absolute defaults for the system binaries: AeroSpace hands `exec-and-forget` a
# minimal PATH, so a bare name is not safe to rely on here. `hs` is the
# exception - Homebrew puts it in one of two prefixes depending on the chip.
PGREP_BIN="$(macos_control_bin "${MACOS_CONTROL_PGREP:-/usr/bin/pgrep}" pgrep)"
OSASCRIPT_BIN="$(macos_control_bin "${MACOS_CONTROL_OSASCRIPT:-/usr/bin/osascript}" osascript)"
OPEN_BIN="$(macos_control_bin "${MACOS_CONTROL_OPEN:-/usr/bin/open}" open)"
HS_BIN="$(macos_control_bin "${HS_BIN:-}" hs)"

BTT_PROCESS_NAME="BetterTouchTool"

# Catalina moved the bundle under /System. Both paths are listed so a probe on
# an older macOS answers honestly instead of reporting no route at all.
MISSION_CONTROL_APPS="${MACOS_CONTROL_MISSION_CONTROL_APP:-/System/Applications/Mission Control.app:/Applications/Mission Control.app}"

HS_SENTINEL="macos-control-ok"

# --- per-action constants ---------------------------------------------------

# BTTPredefinedActionType numbers, the same pair aerospace-gestures.sh binds to
# swipe up and swipe down.
btt_action_for() {
    case "$1" in
        mission-control) printf '7\n' ;;
        app-expose) printf '6\n' ;;
    esac
}

hs_function_for() {
    case "$1" in
        mission-control) printf 'toggleMissionControl\n' ;;
        app-expose) printf 'toggleAppExpose\n' ;;
    esac
}

# Space separated rather than an array: bash 3.2 needs a guard to expand an
# empty array under `set -u`, and there is nothing here worth that.
routes_for() {
    case "$1" in
        mission-control) printf 'bettertouchtool hammerspoon mission-control-app\n' ;;
        app-expose) printf 'bettertouchtool hammerspoon\n' ;;
    esac
}

# --- bettertouchtool --------------------------------------------------------

btt_available() {
    [ -n "$PGREP_BIN" ] || return 1
    [ -n "$OSASCRIPT_BIN" ] || return 1
    "$PGREP_BIN" -x "$BTT_PROCESS_NAME" >/dev/null 2>&1
}

btt_run() {
    btt_available || return 1
    "$OSASCRIPT_BIN" -e \
        "tell application \"BetterTouchTool\" to trigger_action \"{\\\"BTTPredefinedActionType\\\":$(btt_action_for "$1")}\"" \
        >/dev/null 2>&1
}

# --- hammerspoon ------------------------------------------------------------

# `hs -c` prints the snippet's value on stdout, its own chatter ("-- Loading
# extension: spaces") on stderr, and exits 65 with empty stdout when the snippet
# raises. Both halves below are load-bearing: the exit status catches a
# Hammerspoon that is not running, and the sentinel separates "hs.spaces did the
# thing" from a guarded snippet that found no hs.spaces and returned nothing -
# which exits 0.
hs_eval() {
    local lua="$1"
    local answer

    [ -n "$HS_BIN" ] || return 1
    answer="$("$HS_BIN" -c "$lua" 2>/dev/null)" || return 1

    case "$answer" in
        *"$HS_SENTINEL"*) return 0 ;;
    esac
    return 1
}

# hs.spaces arrived in Hammerspoon 0.9.90. The guard is what keeps an older
# install falling through to the next route instead of raising.
hs_available() {
    local fn
    fn="$(hs_function_for "$1")"

    hs_eval "$(printf 'if hs.spaces and hs.spaces.%s then return "%s" end return ""' \
        "$fn" "$HS_SENTINEL")"
}

hs_run() {
    local fn
    fn="$(hs_function_for "$1")"

    hs_eval "$(printf 'if hs.spaces and hs.spaces.%s then hs.spaces.%s() return "%s" end return ""' \
        "$fn" "$fn" "$HS_SENTINEL")"
}

# --- mission control app ----------------------------------------------------

mission_control_app_path() {
    local rest="$MISSION_CONTROL_APPS"
    local candidate

    while [ -n "$rest" ]; do
        candidate="${rest%%:*}"
        if [ "$candidate" = "$rest" ]; then
            rest=""
        else
            rest="${rest#*:}"
        fi

        [ -n "$candidate" ] || continue
        if [ -d "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

mission_control_app_available() {
    [ -n "$OPEN_BIN" ] || return 1
    mission_control_app_path >/dev/null
}

# Re-opening Mission Control.app while Mission Control is showing dismisses it,
# so this toggles like the other two routes rather than only opening.
mission_control_app_run() {
    local app

    [ -n "$OPEN_BIN" ] || return 1
    app="$(mission_control_app_path)" || return 1
    "$OPEN_BIN" -a "$app" >/dev/null 2>&1
}

# --- dispatch ---------------------------------------------------------------

route_available() {
    case "$1" in
        bettertouchtool) btt_available ;;
        hammerspoon) hs_available "$2" ;;
        mission-control-app) mission_control_app_available ;;
        *) return 1 ;;
    esac
}

route_run() {
    case "$1" in
        bettertouchtool) btt_run "$2" ;;
        hammerspoon) hs_run "$2" ;;
        mission-control-app) mission_control_app_run ;;
        *) return 1 ;;
    esac
}

for route in $(routes_for "$action"); do
    if [ "$probe_only" -eq 1 ]; then
        if route_available "$route" "$action"; then
            printf '%s\n' "$route"
            exit 0
        fi
        continue
    fi

    if route_run "$route" "$action"; then
        exit 0
    fi
done

# Nothing left to try. Under `exec-and-forget` nobody reads this line, which is
# why doctor.sh runs `--probe` and reports the same thing where it can be seen.
if [ "$action" = "app-expose" ]; then
    printf 'macos-control.sh: no route for app-expose on this machine. macOS has no App Exposé bundle to open, so this needs Hammerspoon (./bootstrap/setup.sh desktop) or a running BetterTouchTool (./bootstrap/setup.sh extras).\n' >&2
else
    printf 'macos-control.sh: no route for mission-control on this machine. Install Hammerspoon (./bootstrap/setup.sh desktop) or BetterTouchTool (./bootstrap/setup.sh extras), or restore /System/Applications/Mission Control.app.\n' >&2
fi

exit 69
