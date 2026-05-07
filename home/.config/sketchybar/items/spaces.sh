#!/usr/bin/env bash

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13")
MAIN_MONITOR_NAME="${SKETCHYBAR_MAIN_MONITOR_NAME:-PHL 279C9}"
SIDE_MONITOR_NAME="${SKETCHYBAR_SIDE_MONITOR_NAME:-24V5C2}"
STAGE_MONITOR_NAME="${SKETCHYBAR_STAGE_MONITOR_NAME:-Built-in Retina Display}"
AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"

sketchybar --add event aerospace_workspace_change

screen_info_for_monitor() {
  local monitor_name="$1"

  "$HS_BIN" -c 'for _, screen in ipairs(hs.screen.allScreens()) do print(screen:name() .. "\t" .. screen:id() .. "\t" .. screen:getUUID()) end' 2>/dev/null |
    /usr/bin/awk -F '\t' -v name="$monitor_name" '$1 == name { print $2 "\t" $3; exit }'
}

display_id_for_monitor() {
  local monitor_name="$1"
  local screen_info direct_display_id screen_uuid displays_json display_id

  screen_info="$(screen_info_for_monitor "$monitor_name" || true)"
  if [ -n "$screen_info" ]; then
    direct_display_id="$(/usr/bin/printf '%s\n' "$screen_info" | /usr/bin/awk -F '\t' '{ print $1; exit }')"
    screen_uuid="$(/usr/bin/printf '%s\n' "$screen_info" | /usr/bin/awk -F '\t' '{ print $2; exit }')"
    displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null || true)"

    display_id="$(/usr/bin/python3 - "$direct_display_id" "$screen_uuid" "$displays_json" <<'PY' || true
import json
import sys

direct_display_id = sys.argv[1]
screen_uuid = sys.argv[2]
payload = sys.argv[3]

try:
    displays = json.loads(payload)
except json.JSONDecodeError:
    raise SystemExit(0)

for display in displays:
    if str(display.get("UUID")) == screen_uuid or str(display.get("DirectDisplayID")) == direct_display_id:
        print(display.get("arrangement-id"))
        break
PY
)"

    if [ -n "$display_id" ]; then
      /usr/bin/printf '%s\n' "$display_id"
      return
    fi
  fi

  "$AEROSPACE_BIN" list-monitors --format '%{monitor-name}	%{monitor-appkit-nsscreen-screens-id}' 2>/dev/null |
    /usr/bin/awk -F '\t' -v name="$monitor_name" '$1 == name { print $2; exit }'
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
  click_script="$PLUGIN_DIR/aerospace_spaces.sh"
  script="$PLUGIN_DIR/aerospace_spaces.sh"
  icon.color=$ORANGE
)

sketchybar --add item space_creator left                 \
           --set space_creator "${space_creator[@]}"     \
           --subscribe space_creator aerospace_workspace_change front_app_switched

"$PLUGIN_DIR/aerospace_spaces.sh"
