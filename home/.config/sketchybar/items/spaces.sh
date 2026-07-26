#!/usr/bin/env bash

# Workspace items on the bar. Which workspaces exist and which display each one
# belongs to both come from ~/.config/aerospace/, so this file no longer
# repeats "thirteen workspaces" or the names of one particular set of monitors.
#
# Why the AeroSpace config and not a SketchyBar one: these items exist to show
# AeroSpace workspaces, and two sources of truth for the same list is how they
# end up disagreeing. lib/workspaces.sh owns the lookup and its fallbacks so
# this file and the plugin that repaints the chips cannot answer differently.

AEROSPACE_CONFIG_DIR="${AEROSPACE_CONFIG_DIR:-$HOME/.config/aerospace}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"

source "$CONFIG_DIR/lib/theme.sh"
source "$CONFIG_DIR/lib/workspaces.sh"
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
#
# Assigns into a named variable rather than printing: a command substitution is
# a subshell, and the resolver's "warn once" guard cannot survive one, so three
# roles used to produce three copies of the same warning.
resolve_display_id() {
  local role="$1"
  local target="$2"
  local monitor_name display_id=""

  monitor_name="$(monitor_name_for_role "$role")"
  if [ -n "$monitor_name" ]; then
    sketchybar_display_id_for_monitor_var "$monitor_name" || true
    display_id="$SKETCHYBAR_DISPLAY_ID"
  fi

  if [ -z "$display_id" ] && [ "$role" != "main" ]; then
    display_id="$main_display"
  fi

  eval "$target=\"\${display_id:-1}\""
}

resolve_display_id main main_display
resolve_display_id side side_display
resolve_display_id stage stage_display

for sid in $(sketchybar_workspace_list); do
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
    icon.highlight_color=$THEME_ACCENT_WORKSPACE_ACTIVE
    label.color=$THEME_ACCENT_WORKSPACE_IDLE
    label.highlight_color=$THEME_ACCENT_ON_ACCENT
    label.font="$THEME_FONT_APP_ICON"
    label.y_offset=-1
    background.color=$BACKGROUND_1
    background.border_color=$BACKGROUND_2
    script="$PLUGIN_DIR/space.sh"
  )

  sketchybar --add item space.$sid left       \
             --set space.$sid "${space[@]}"  \
             --subscribe space.$sid mouse.clicked
done

# The refresh item exists to re-read AeroSpace. Without the binary it would
# fire on every app switch, find nothing, and log a warning each time, so it is
# simply not added - the chips above still show the configured workspaces.
if sketchybar_runtime_has "$(sketchybar_runtime_bin "${AEROSPACE_BIN:-${AEROSPACE:-}}" aerospace)"; then
  space_creator=(
    icon=􀆊
    icon.font="$THEME_FONT_HEAVY"
    padding_left=10
    padding_right=8
    label.drawing=off
    display=active
    click_script="$PLUGIN_DIR/aerospace_spaces_refresh.sh"
    script="$PLUGIN_DIR/aerospace_spaces_refresh.sh"
    icon.color=$THEME_ACCENT_WORKSPACE_ADD
  )

  sketchybar --add item space_creator left                 \
             --set space_creator "${space_creator[@]}"     \
             --subscribe space_creator aerospace_workspace_change front_app_switched

  "$PLUGIN_DIR/aerospace_spaces_refresh.sh"
fi
