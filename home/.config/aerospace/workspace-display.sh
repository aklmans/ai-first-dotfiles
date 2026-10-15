#!/usr/bin/env bash
set -euo pipefail

# Move a whole workspace by changing its remembered display preference. Keep
# role defaults as fallbacks when that display is disconnected.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/layout.sh"
source "$SCRIPT_DIR/lib/write-guard.sh"
AEROSPACE="$(aerospace_layout_bin)"
config="${AEROSPACE_CONFIG_PATH:-$HOME/.aerospace.toml}"
preferences="${AEROSPACE_WORKSPACE_MONITORS_FILE:-$AEROSPACE_CONFIG_DIR/workspace-monitors.conf}"
action="${1:-help}"
target=""
case "$action" in
    set) target="${2:-}"; workspace="${3:-}" ;;
    next|prev|reset) workspace="${2:-}" ;;
    *) printf 'Usage: workspace-display.sh {next|prev|reset} [workspace]\n       workspace-display.sh set <monitor-id> [workspace]\nMoves the whole workspace and remembers its display. reset restores the role default.\n'; exit 64 ;;
esac

workspace="${workspace:-$("$AEROSPACE" list-workspaces --focused)}"
aerospace_layout_workspace_is_configured "$workspace" || { printf 'Unknown workspace: %s\n' "$workspace" >&2; exit 64; }
aerospace_layout_monitor_override '' >/dev/null

monitor_name=""
if [ "$action" != reset ]; then
    monitors="$("$AEROSPACE" list-monitors --format '%{monitor-id}%{tab}%{monitor-name}')"
    if [ "$action" != set ]; then
        placements="$("$AEROSPACE" list-workspaces --all --format '%{workspace}%{tab}%{monitor-id}')"
        current="$(printf '%s\n' "$placements" | awk -F '\t' -v ws="$workspace" '$1==ws {print $2}')"
        target="$(printf '%s\n' "$monitors" | awk -F '\t' -v current="$current" -v direction="$action" '
            NF>=2 { ids[++n]=$1; if ($1==current) at=n }
            END { if (!at || n<2) exit 1; i=(direction=="next" ? at % n+1 : (at+n-2)%n+1); print ids[i] }')" || {
            printf 'At least two connected displays and a placed workspace are required.\n' >&2; exit 1;
        }
    fi
    case "$target" in ''|*[!0-9]*) printf 'Expected a connected monitor ID.\n' >&2; exit 64 ;; esac
    monitor_name="$(printf '%s\n' "$monitors" | awk -F '\t' -v id="$target" '$1==id {print $2}')"
    case "$monitor_name" in ''|*'|'*|*$'\n'*|*$'\r'*) printf 'Missing or ambiguous display identity.\n' >&2; exit 65 ;; esac
    matches="$(printf '%s\n' "$monitors" | awk -F '\t' -v name="$monitor_name" '$2==name {n++} END {print n+0}')"
    [ "$matches" = 1 ] || { printf 'Display names must be unique to remember a preference.\n' >&2; exit 65; }
fi

ai_first_write_path_check "$preferences"
ai_first_write_path_check "$config"
ai_first_write_lock_acquire
work="$(mktemp -d "${TMPDIR:-/tmp}/workspace-display.XXXXXX")"
trap 'rm -rf "$work"; ai_first_write_lock_release' EXIT
original_config="$(ai_first_file_state "$config")"
original_preferences="$(ai_first_file_state "$preferences")"
cp -p "$config" "$work/config.before"
if [ -f "$preferences" ]; then cp -p "$preferences" "$work/preferences.before"; else : > "$work/preferences.before"; fi
awk -F '|' -v ws="$workspace" '$1!=ws' "$work/preferences.before" > "$work/preferences.after"
if [ "$action" != reset ]; then printf '%s|%s\n' "$workspace" "$monitor_name" >> "$work/preferences.after"; fi

# Render and validate BEFORE changing either live file. App routes are unrelated.
AEROSPACE_WORKSPACE_MONITORS_FILE="$work/preferences.after" \
    /bin/bash "$SCRIPT_DIR/render-layout.sh" --stdout --no-app-rules "$config" > "$work/config.after"

mkdir -p "$(dirname "$preferences")"
if [ "$original_preferences" = absent ]; then
    [ "$(ai_first_file_state "$preferences")" = absent ] || exit 75
    staged="$(mktemp "${preferences}.new.XXXXXX")"
    cp "$work/preferences.after" "$staged"
    chmod 600 "$staged"
    mv "$staged" "$preferences"
else
    ai_first_replace_file "$work/preferences.after" "$preferences" workspace-display "$original_preferences"
fi

rollback_preferences() {
    # Never overwrite an unrelated edit made outside our cooperative lock.
    cmp -s "$preferences" "$work/preferences.after" || return 1
    if [ "$original_preferences" = absent ]; then
        rm "$preferences"
    else
        ai_first_replace_file "$work/preferences.before" "$preferences" workspace-display-rollback
    fi
}

if ! ai_first_replace_file "$work/config.after" "$config" workspace-display "$original_config"; then
    rollback_preferences
    exit 1
fi
if ! "$AEROSPACE" reload-config --dry-run --no-gui || ! "$AEROSPACE" reload-config; then
    if cmp -s "$config" "$work/config.after"; then
        ai_first_replace_file "$work/config.before" "$config" workspace-display-rollback
        rollback_preferences
        "$AEROSPACE" reload-config || true
    fi
    printf 'Display change failed; previous configuration restored where unchanged.\n' >&2
    exit 1
fi
"$AEROSPACE" workspace "$workspace"
bar="${CONFIG_DIR:-$HOME/.config/sketchybar}"
if [ -f "$bar/plugins/display_rebind.sh" ]; then /bin/bash "$bar/plugins/display_rebind.sh"; fi
if [ -f "$bar/plugins/aerospace_spaces_refresh.sh" ]; then /bin/bash "$bar/plugins/aerospace_spaces_refresh.sh"; fi
printf 'Workspace %s: %s\n' "$workspace" "${monitor_name:-role default restored}"
