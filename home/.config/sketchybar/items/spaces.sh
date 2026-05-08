#!/usr/bin/env bash

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13")
MAIN_MONITOR_NAME="${SKETCHYBAR_MAIN_MONITOR_NAME:-PHL 279C9}"
SIDE_MONITOR_NAME="${SKETCHYBAR_SIDE_MONITOR_NAME:-24V5C2}"
STAGE_MONITOR_NAME="${SKETCHYBAR_STAGE_MONITOR_NAME:-Built-in Retina Display}"
AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"

source "$CONFIG_DIR/lib/display-resolver.sh"

sketchybar --add event aerospace_workspace_change

display_id_for_monitor() {
  local monitor_name="$1"
  sketchybar_display_id_for_monitor "$monitor_name"
}

display_id_for_role() {
  local role="$1"
  local display_id=""

  case "$role" in
    main)
      display_id="$(display_id_for_monitor "$MAIN_MONITOR_NAME" || true)"
      ;;
    side)
      display_id="$(display_id_for_monitor "$SIDE_MONITOR_NAME" || true)"
      ;;
    stage)
      display_id="$(display_id_for_monitor "$STAGE_MONITOR_NAME" || true)"
      ;;
  esac

  if [ -n "$display_id" ]; then
    printf '%s\n' "$display_id"
    return
  fi

  case "$role" in
    main)
      printf '1\n'
      ;;
    side)
      printf '2\n'
      ;;
    stage)
      printf '3\n'
      ;;
  esac
}

main_display="$(display_id_for_role main)"
side_display="$(display_id_for_role side)"
stage_display="$(display_id_for_monitor "$STAGE_MONITOR_NAME" || true)"
if [ -z "$stage_display" ]; then
  stage_display="$side_display"
fi

for i in "${!SPACE_ICONS[@]}"; do
  sid=$((i + 1))
  display="$main_display"
  if [ "$sid" -gt 6 ]; then
    display="$side_display"
  fi
  if [ "$sid" -eq 13 ]; then
    display="$stage_display"
  fi

  space=(
    display=$display
    icon="${SPACE_ICONS[i]}"
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
