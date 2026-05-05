#!/bin/bash

front_app=(
  icon.font="sketchybar-app-font:Regular:16.0" # This is a custom font for icon="$($CONFIG_DIR/plugins/icon_map.sh "$INFO")"
  icon.color=$BLUE
  label.font="$FONT:Black:14.0"
  icon.background.drawing=on
  display=active
  script="$PLUGIN_DIR/front_app.sh"
  click_script="open -a 'Mission Control'"
)

sketchybar --add item front_app left         \
           --set front_app "${front_app[@]}" \
           --subscribe front_app front_app_switched
