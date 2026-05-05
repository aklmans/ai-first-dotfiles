#!/usr/bin/env bash
set -euo pipefail

AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_SPACES="${SKETCHYBAR_SPACES:-$HOME/.config/sketchybar/plugins/aerospace_spaces.sh}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

action="${1:-}"

if [ -r "$SCRIPT_DIR/app-defaults.sh" ]; then
    source "$SCRIPT_DIR/app-defaults.sh"
fi

aerospace_cmd() {
    local status=0

    for _ in 1 2 3; do
        if "$AEROSPACE_BIN" "$@"; then
            return 0
        fi
        status=$?
        /bin/sleep 0.15
    done

    return "$status"
}

refresh_spaces() {
    if [ -x "$SKETCHYBAR_SPACES" ]; then
        /bin/bash "$SKETCHYBAR_SPACES" >/dev/null 2>&1 || true
    fi
}

focused_window() {
    aerospace_cmd list-windows --focused --format "%{window-id}%{tab}%{workspace}%{tab}%{app-bundle-id}%{tab}%{window-layout}"
}

workspace_windows() {
    aerospace_cmd list-windows --workspace focused --format "%{window-id}%{tab}%{workspace}%{tab}%{app-bundle-id}%{tab}%{window-layout}"
}

workspace_windows_with_metadata() {
    aerospace_cmd list-windows --workspace focused --format "%{window-id}%{tab}%{workspace}%{tab}%{app-bundle-id}%{tab}%{app-name}%{tab}%{window-title}%{tab}%{window-layout}"
}

layout_target_for_lines() {
    local lines="$1"

    if [ -z "$lines" ]; then
        printf 'tiling\n'
        return
    fi

    if printf '%s\n' "$lines" | /usr/bin/awk -F '\t' '$4 != "floating" { found = 1 } END { exit found ? 0 : 1 }'; then
        printf 'floating\n'
    else
        printf 'tiling\n'
    fi
}

layout_window() {
    local window_id="$1"
    local target="$2"

    [ -n "$window_id" ] || return 0
    aerospace_cmd layout --window-id "$window_id" "$target" >/dev/null
}

toggle_window() {
    local line window_id layout target

    line="$(focused_window)"
    IFS=$'\t' read -r window_id _ _ layout <<<"$line"
    if [ "$layout" = "floating" ]; then
        target="tiling"
    else
        target="floating"
    fi
    layout_window "$window_id" "$target"
}

toggle_current_app_in_workspace() {
    local focused workspace bundle lines target

    focused="$(focused_window)"
    IFS=$'\t' read -r _ workspace bundle _ <<<"$focused"
    lines="$(workspace_windows | /usr/bin/awk -F '\t' -v workspace="$workspace" -v bundle="$bundle" '$2 == workspace && $3 == bundle')"
    target="$(layout_target_for_lines "$lines")"

    printf '%s\n' "$lines" | while IFS=$'\t' read -r window_id _ _ _; do
        layout_window "$window_id" "$target"
    done
}

toggle_workspace() {
    local lines target

    lines="$(workspace_windows)"
    target="$(layout_target_for_lines "$lines")"
    printf '%s\n' "$lines" | while IFS=$'\t' read -r window_id _ _ _; do
        layout_window "$window_id" "$target"
    done
}

repair_workspace() {
    local lines target first_tiling_window

    lines="$(workspace_windows_with_metadata)"
    first_tiling_window=""

    while IFS=$'\t' read -r window_id _ app_id app_name title _; do
        target="tiling"
        if type should_float_window >/dev/null 2>&1 && should_float_window "$app_id" "$app_name" "$title"; then
            target="floating"
        elif [ -z "$first_tiling_window" ]; then
            first_tiling_window="$window_id"
        fi
        layout_window "$window_id" "$target"
    done <<< "$lines"

    if [ -n "$first_tiling_window" ]; then
        aerospace_cmd focus --window-id "$first_tiling_window" >/dev/null 2>&1 || true
    fi

    aerospace_cmd flatten-workspace-tree >/dev/null
    aerospace_cmd layout tiles horizontal vertical >/dev/null
    aerospace_cmd balance-sizes >/dev/null
}

tiles_workspace() {
    aerospace_cmd layout tiles horizontal vertical >/dev/null
}

balance_workspace() {
    aerospace_cmd balance-sizes >/dev/null
}

case "$action" in
    toggle-window)
        toggle_window
        ;;
    toggle-app)
        toggle_current_app_in_workspace
        ;;
    toggle-workspace)
        toggle_workspace
        ;;
    repair-workspace)
        repair_workspace
        ;;
    tiles)
        tiles_workspace
        ;;
    balance)
        balance_workspace
        ;;
    *)
        printf 'Usage: %s {toggle-window|toggle-app|toggle-workspace|repair-workspace|tiles|balance}\n' "$0" >&2
        exit 64
        ;;
esac

refresh_spaces
