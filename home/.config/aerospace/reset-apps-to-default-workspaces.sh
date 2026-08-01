#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/app-defaults.sh"

aerospace list-windows --all --format '%{window-id}%{tab}%{app-bundle-id}%{tab}%{app-name}%{tab}%{window-title}' |
    while IFS=$'\t' read -r window_id app_id app_name title; do
        if should_float_window "$app_id" "$app_name" "$title"; then
            aerospace layout --window-id "$window_id" floating 2>/dev/null || true
        elif should_tile_window "$app_id" "$app_name" "$title"; then
            aerospace layout --window-id "$window_id" tiling 2>/dev/null || true
        fi

        route_policy="$(aerospace_route_field "$app_id" "$app_name" policy 2>/dev/null || true)"
        target_workspace=""
        if [ "$route_policy" = 'fixed' ]; then
            target_workspace="$(default_workspace_for_window "$app_id" "$app_name" "$title" || true)"
        fi
        if [ -n "$target_workspace" ]; then
            aerospace move-node-to-workspace --window-id "$window_id" "$target_workspace" 2>/dev/null || true
        fi
    done

if [ -x "$HOME/.config/sketchybar/plugins/aerospace_spaces.sh" ]; then
    "$HOME/.config/sketchybar/plugins/aerospace_spaces.sh" >/dev/null 2>&1 || true
fi
