#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
ICON_MAP="$CONFIG_DIR/plugins/icon_map.sh"

source "$CONFIG_DIR/lib/theme.sh"
source "$CONFIG_DIR/lib/runtime.sh"
source "$CONFIG_DIR/lib/workspaces.sh"

SKETCHYBAR="${SKETCHYBAR:-$(sketchybar_runtime_bin "" sketchybar)}"
SKETCHYBAR="${SKETCHYBAR:-/opt/homebrew/bin/sketchybar}"
AEROSPACE="${AEROSPACE:-$(sketchybar_runtime_bin "" aerospace)}"

# No AeroSpace means no windows to report and no workspaces to repaint. Saying
# so once and leaving the chips alone beats a screenful of "command not found"
# and beats wiping every label to "-".
if ! sketchybar_runtime_has "$AEROSPACE"; then
  sketchybar_warn_once aerospace-missing \
    'aerospace CLI not found; workspace chips will not be repainted. Install AeroSpace, or set AEROSPACE to its path.'
  exit 0
fi

run_aerospace() {
  "$AEROSPACE" "$@" 2>/dev/null
}

# The one list, shared with items/spaces.sh, so a chip is never repainted that
# was never created - and never left stale because it was.
WORKSPACES="$(sketchybar_workspace_list)"

collect_windows() {
  local windows
  windows="$(run_aerospace list-windows --all --format "%{workspace}%{tab}%{app-name}" || true)"
  if [ -n "$windows" ]; then
    printf '%s\n' "$windows"
    return 0
  fi

  local workspace
  for workspace in $WORKSPACES; do
    run_aerospace list-windows --workspace "$workspace" --format "%{workspace}%{tab}%{app-name}" || true
  done
}

WINDOWS="$(collect_windows)"
focused_workspace="$(run_aerospace list-workspaces --focused | head -n 1 || true)"

args=(--animate sin 10)

for workspace in $WORKSPACES; do
  selected=false
  border_color="$BACKGROUND_2"
  icon_color="$ICON_COLOR"
  label=" "

  apps="$(
    printf '%s\n' "$WINDOWS" |
      awk -F "$(printf '\t')" -v workspace="$workspace" '$1 == workspace && $2 != "" && $2 != "Typeless" { print $2 }' |
      sort -u
  )"

  if [ -n "$apps" ]; then
    while IFS= read -r app_name; do
      [ -n "$app_name" ] || continue
      label="$label $("$ICON_MAP" "$app_name" 2>/dev/null || printf ':default:')"
    done <<< "$apps"
  else
    label=" -"
  fi

  if [ "$workspace" = "$focused_workspace" ]; then
    selected=true
    border_color="$THEME_ACCENT_WORKSPACE_ACTIVE"
    icon_color="$THEME_ACCENT_WORKSPACE_ACTIVE"
  fi

  args+=(
    --set "space.$workspace"
    icon.color="$icon_color"
    icon.highlight="$selected"
    label="$label"
    label.highlight="$selected"
    background.border_color="$border_color"
  )
done

"$SKETCHYBAR" "${args[@]}" >/dev/null 2>&1 || true
