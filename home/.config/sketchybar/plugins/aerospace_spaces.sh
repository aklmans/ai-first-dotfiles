#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SKETCHYBAR="${SKETCHYBAR:-/opt/homebrew/bin/sketchybar}"
AEROSPACE="${AEROSPACE:-/opt/homebrew/bin/aerospace}"
ICON_MAP="$CONFIG_DIR/plugins/icon_map.sh"

source "$CONFIG_DIR/colors.sh"

run_aerospace() {
  "$AEROSPACE" "$@" 2>/dev/null
}

WORKSPACES="1 2 3 4 5 6 7 8 9 10 11 12 13"
WINDOWS="$(run_aerospace list-windows --all --format "%{workspace}%{tab}%{app-name}" || true)"
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
    border_color="$BLUE"
    icon_color="$BLUE"
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
