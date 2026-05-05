#!/usr/bin/env bash

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12")

sketchybar --add event aerospace_workspace_change

for i in "${!SPACE_ICONS[@]}"; do
  sid=$((i + 1))
  display=1
  if [ "$sid" -gt 6 ]; then
    display=2
  fi

  space=(
    display=$display
    icon="${SPACE_ICONS[i]}"
    icon.padding_left=10
    icon.padding_right=10
    padding_left=2
    padding_right=2
    label.padding_right=20
    icon.highlight_color=$MAGENTA
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
