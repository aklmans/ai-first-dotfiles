#!/usr/bin/env bash

# Workspace items on the bar. Which workspaces exist and which display each one
# belongs to both come from ~/.config/aerospace/, so this file no longer
# repeats "thirteen workspaces" or the names of one particular set of monitors.
#
# Why the AeroSpace config and not a SketchyBar one: these items exist to show
# AeroSpace workspaces, and two sources of truth for the same list is how they
# end up disagreeing.

AEROSPACE_CONFIG_DIR="${AEROSPACE_CONFIG_DIR:-$HOME/.config/aerospace}"
AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"

source "$CONFIG_DIR/lib/display-resolver.sh"

# Environment overrides are still honoured by the library itself; naming them
# here keeps the old SKETCHYBAR_*_MONITOR_NAME variables working for anyone who
# set them before displays.conf existed.
AEROSPACE_MAIN_MONITOR_NAME="${SKETCHYBAR_MAIN_MONITOR_NAME:-${AEROSPACE_MAIN_MONITOR_NAME:-}}"
AEROSPACE_SIDE_MONITOR_NAME="${SKETCHYBAR_SIDE_MONITOR_NAME:-${AEROSPACE_SIDE_MONITOR_NAME:-}}"
AEROSPACE_STAGE_MONITOR_NAME="${SKETCHYBAR_STAGE_MONITOR_NAME:-${AEROSPACE_STAGE_MONITOR_NAME:-}}"

if [ -r "$AEROSPACE_CONFIG_DIR/lib/layout.sh" ]; then
  source "$AEROSPACE_CONFIG_DIR/lib/layout.sh"
  aerospace_layout_load_config
  aerospace_layout_resolve
fi

sketchybar --add event aerospace_workspace_change

workspace_list() {
  if type aerospace_layout_workspaces >/dev/null 2>&1; then
    aerospace_layout_workspaces
    return
  fi
  printf '1 2 3 4 5 6 7 8 9 10 11 12 13\n'
}

role_for_workspace() {
  if type aerospace_layout_role_for_workspace >/dev/null 2>&1; then
    aerospace_layout_role_for_workspace "$1" 2>/dev/null || printf 'main\n'
    return
  fi
  printf 'main\n'
}

monitor_name_for_role() {
  local role="$1"

  if type aerospace_layout_resolved_name >/dev/null 2>&1; then
    aerospace_layout_resolved_name "$role"
    return
  fi

  case "$role" in
    main) printf '%s\n' "$AEROSPACE_MAIN_MONITOR_NAME" ;;
    side) printf '%s\n' "$AEROSPACE_SIDE_MONITOR_NAME" ;;
    stage) printf '%s\n' "$AEROSPACE_STAGE_MONITOR_NAME" ;;
    *) printf '\n' ;;
  esac
}

main_display=""

# Arrangement id 1 always exists, so an unresolvable role puts its workspaces on
# a real display instead of on display 2 or 3 of a laptop that has neither.
display_id_for_role() {
  local role="$1"
  local monitor_name display_id=""

  monitor_name="$(monitor_name_for_role "$role")"
  if [ -n "$monitor_name" ]; then
    display_id="$(sketchybar_display_id_for_monitor "$monitor_name" || true)"
  fi

  if [ -z "$display_id" ] && [ "$role" != "main" ]; then
    display_id="$main_display"
  fi

  printf '%s\n' "${display_id:-1}"
}

main_display="$(display_id_for_role main)"
side_display="$(display_id_for_role side)"
stage_display="$(display_id_for_role stage)"

for sid in $(workspace_list); do
  case "$(role_for_workspace "$sid")" in
    side)
      display="$side_display"
      ;;
    stage)
      display="$stage_display"
      ;;
    *)
      display="$main_display"
      ;;
  esac

  space=(
    display=$display
    icon="$sid"
    icon.padding_left=10
    icon.padding_right=10
    padding_left=2
    padding_right=2
    label.padding_right=20
    icon.highlight_color=$BLUE
    label.color=$GREY
    label.highlight_color=$WHITE
    label.font="sketchybar-app-font:Regular:16.0"
    label.y_offset=-1
    background.color=$BACKGROUND_1
    background.border_color=$BACKGROUND_2
    script="$PLUGIN_DIR/space.sh"
  )

  sketchybar --add item space.$sid left       \
             --set space.$sid "${space[@]}"  \
             --subscribe space.$sid mouse.clicked
done

space_creator=(
  icon=􀆊
  icon.font="$FONT:Heavy:16.0"
  padding_left=10
  padding_right=8
  label.drawing=off
  display=active
  click_script="$PLUGIN_DIR/aerospace_spaces_refresh.sh"
  script="$PLUGIN_DIR/aerospace_spaces_refresh.sh"
  icon.color=$ORANGE
)

sketchybar --add item space_creator left                 \
           --set space_creator "${space_creator[@]}"     \
           --subscribe space_creator aerospace_workspace_change front_app_switched

"$PLUGIN_DIR/aerospace_spaces_refresh.sh"
