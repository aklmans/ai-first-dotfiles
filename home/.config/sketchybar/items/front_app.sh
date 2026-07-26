#!/bin/bash

front_app=(
  icon.font="$THEME_FONT_APP_ICON" # Custom font for icon="$($CONFIG_DIR/plugins/icon_map.sh "$INFO")"
  icon.color=$THEME_ACCENT_FRONT_APP
  label.font="$THEME_FONT_TITLE"
  icon.background.drawing=on
  display=active
  script="$PLUGIN_DIR/front_app.sh"
  click_script="open -a 'Mission Control'"
)

sketchybar --add item front_app left         \
           --set front_app "${front_app[@]}" \
           --subscribe front_app front_app_switched
