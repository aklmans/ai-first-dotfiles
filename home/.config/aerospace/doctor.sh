#!/usr/bin/env bash
set -uo pipefail

AEROSPACE_CONFIG="$HOME/.aerospace.toml"
AEROSPACE_DIR="$HOME/.config/aerospace"
SKETCHYBAR_PLUGINS="$HOME/.config/sketchybar/plugins"
HAMMERSPOON_CONFIG="$HOME/.hammerspoon/init.lua"
CHECK_TIMEOUT_SECONDS="${DOTFILES_DOCTOR_TIMEOUT_SECONDS:-5}"

issues=0
warnings=0

ok() {
    printf 'OK    %s\n' "$*"
}

warn() {
    printf 'WARN  %s\n' "$*"
    warnings=$((warnings + 1))
}

fail() {
    printf 'FAIL  %s\n' "$*"
    issues=$((issues + 1))
}

check_command() {
    local command_name="$1"
    if command -v "$command_name" >/dev/null 2>&1; then
        ok "command available: $command_name"
    else
        fail "command missing: $command_name"
    fi
}

run_check() {
    # A check that degrades the desktop rather than breaking it passes --warn
    # first. Two shortcuts falling back to a different route is worth saying out
    # loud; it is not a reason for this script to exit non-zero.
    local severity=fail
    if [ "${1:-}" = "--warn" ]; then
        severity=warn
        shift
    fi

    local label="$1"
    shift

    local output output_file timeout_file pid watchdog_pid status
    output_file="$(mktemp)"
    timeout_file="$(mktemp)"
    rm -f "$timeout_file"

    "$@" >"$output_file" 2>&1 &
    pid="$!"

    (
        sleep "$CHECK_TIMEOUT_SECONDS"
        if kill -0 "$pid" >/dev/null 2>&1; then
            printf 'timeout\n' >"$timeout_file"
            kill "$pid" >/dev/null 2>&1 || true
            sleep 0.2
            kill -9 "$pid" >/dev/null 2>&1 || true
        fi
    ) &
    watchdog_pid="$!"

    wait "$pid" 2>/dev/null
    status="$?"
    kill "$watchdog_pid" >/dev/null 2>&1 || true
    wait "$watchdog_pid" >/dev/null 2>&1 || true

    output="$(cat "$output_file")"

    if [ -s "$timeout_file" ]; then
        "$severity" "$label"
        printf '      timed out after %ss\n' "$CHECK_TIMEOUT_SECONDS"
    elif [ "$status" -eq 0 ]; then
        ok "$label"
    else
        "$severity" "$label"
        if [ -n "$output" ]; then
            printf '%s\n' "$output" | sed 's/^/      /' | head -n 6
        fi
    fi

    rm -f "$output_file" "$timeout_file"
}

check_file_executable() {
    local path="$1"
    if [ -x "$path" ]; then
        ok "executable: $path"
    elif [ -e "$path" ]; then
        fail "not executable: $path"
    else
        fail "missing: $path"
    fi
}

# Libraries and config files are sourced, not run, so an executable bit on them
# is neither required nor a problem.
check_file_readable() {
    local path="$1"
    if [ -r "$path" ]; then
        ok "readable: $path"
    else
        fail "missing: $path"
    fi
}

check_app_rules_drift() {
    local generated current generated_clean current_clean
    generated="$(mktemp)"
    current="$(mktemp)"
    generated_clean="$(mktemp)"
    current_clean="$(mktemp)"

    "$AEROSPACE_DIR/app-defaults.sh" --toml > "$generated"
    awk '
        /^# Application placement and floating rules\./ { capture = 1 }
        /^\[mode\.main\.binding\]/ { capture = 0 }
        capture { print }
    ' "$AEROSPACE_CONFIG" > "$current"

    grep -v '^[[:space:]]*$' "$generated" > "$generated_clean"
    grep -v '^[[:space:]]*$' "$current" > "$current_clean"

    if diff -q "$generated_clean" "$current_clean" >/dev/null 2>&1; then
        ok "AeroSpace app rules match app-defaults.sh"
    else
        fail "AeroSpace app rules drift from app-defaults.sh"
        diff -u "$current_clean" "$generated_clean" | head -n 40 | sed 's/^/      /'
    fi

    rm -f "$generated" "$current" "$generated_clean" "$current_clean"
}

printf 'AeroSpace desktop environment doctor\n\n'

check_command aerospace
check_command sketchybar
check_command hs
check_command lua

printf '\nCore services\n'
run_check "AeroSpace server responds" aerospace list-monitors --count
run_check "AeroSpace config dry-run" aerospace reload-config --dry-run --no-gui
run_check "SketchyBar responds" sketchybar --query bar
run_check "Hammerspoon CLI responds" hs -c 'return true'

# Ctrl+Up and Ctrl+Down run under `exec-and-forget`, which reads no output at
# all, so a machine with nothing left to serve them has no other way to say so.
# `--probe` names the route and runs nothing, and the failing output it prints
# is the sentence that says which install would fix it.
run_check --warn "Ctrl+Up has a Mission Control route" \
    "$AEROSPACE_DIR/macos-control.sh" --probe mission-control
run_check --warn "Ctrl+Down has an App Exposé route" \
    "$AEROSPACE_DIR/macos-control.sh" --probe app-expose

printf '\nSyntax\n'
run_check "Hammerspoon Lua syntax" lua -e "assert(loadfile('$HAMMERSPOON_CONFIG'))"
run_check "layout.sh syntax" bash -n "$AEROSPACE_DIR/lib/layout.sh"
run_check "app-defaults.sh syntax" bash -n "$AEROSPACE_DIR/app-defaults.sh"
run_check "app-route.sh syntax" bash -n "$AEROSPACE_DIR/app-route.sh"
run_check "plan.sh syntax" bash -n "$AEROSPACE_DIR/plan.sh"
run_check "focus-workspace-arrow.sh syntax" bash -n "$AEROSPACE_DIR/focus-workspace-arrow.sh"
run_check "reset-apps-to-default-workspaces.sh syntax" bash -n "$AEROSPACE_DIR/reset-apps-to-default-workspaces.sh"
run_check "check-display-layout.sh syntax" bash -n "$AEROSPACE_DIR/check-display-layout.sh"
run_check "macos-control.sh syntax" bash -n "$AEROSPACE_DIR/macos-control.sh"
run_check "toggle-sketchybar-space.sh syntax" bash -n "$AEROSPACE_DIR/toggle-sketchybar-space.sh"
run_check "render-layout.sh syntax" bash -n "$AEROSPACE_DIR/render-layout.sh"
run_check "aerospace_spaces.sh syntax" bash -n "$SKETCHYBAR_PLUGINS/aerospace_spaces.sh"
run_check "layout plugin syntax" bash -n "$SKETCHYBAR_PLUGINS/aerospace_layout.sh"

printf '\nLayout\n'
run_check "display layout matches profile" "$AEROSPACE_DIR/check-display-layout.sh"
# The generated blocks of the AeroSpace config against the workspace and
# display config they come from. Out of date means someone edited
# workspaces.conf or displays.conf and has not run render-layout.sh yet, which
# is a one-command fix the report names.
run_check "AeroSpace config matches workspaces.conf" "$AEROSPACE_DIR/render-layout.sh" --check "$AEROSPACE_CONFIG"
check_app_rules_drift
run_check "workspace roles and app routes resolve" "$AEROSPACE_DIR/plan.sh" --check

printf '\nFiles\n'
check_file_readable "$AEROSPACE_DIR/lib/layout.sh"
check_file_readable "$AEROSPACE_DIR/displays.conf"
check_file_readable "$AEROSPACE_DIR/workspaces.conf"
check_file_executable "$AEROSPACE_DIR/app-defaults.sh"
check_file_executable "$AEROSPACE_DIR/app-route.sh"
check_file_executable "$AEROSPACE_DIR/plan.sh"
check_file_executable "$AEROSPACE_DIR/focus-workspace-arrow.sh"
check_file_executable "$AEROSPACE_DIR/reset-apps-to-default-workspaces.sh"
check_file_executable "$AEROSPACE_DIR/check-display-layout.sh"
check_file_executable "$AEROSPACE_DIR/macos-control.sh"
check_file_executable "$AEROSPACE_DIR/toggle-sketchybar-space.sh"
check_file_executable "$AEROSPACE_DIR/render-layout.sh"
check_file_executable "$SKETCHYBAR_PLUGINS/aerospace_spaces.sh"
check_file_executable "$SKETCHYBAR_PLUGINS/aerospace_layout.sh"

printf '\nSystem preferences\n'
if defaults read -g NSWindowShouldDragOnGesture >/dev/null 2>&1; then
    drag_enabled="$(defaults read -g NSWindowShouldDragOnGesture 2>/dev/null || true)"
    if [ "$drag_enabled" = "1" ]; then
        ok "native Ctrl+Cmd window drag is enabled"
    else
        warn "native Ctrl+Cmd window drag is not enabled"
    fi
else
    warn "native Ctrl+Cmd window drag preference is unset"
fi

printf '\nSummary\n'
if [ "$issues" -eq 0 ]; then
    printf 'OK: no blocking issues'
    if [ "$warnings" -gt 0 ]; then
        printf ', %s warning(s)' "$warnings"
    fi
    printf '.\n'
    exit 0
fi

printf 'FAIL: %s issue(s), %s warning(s).\n' "$issues" "$warnings"
exit 1
