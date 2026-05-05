#!/bin/bash

source "$CONFIG_DIR/colors.sh"

if [ "$SENDER" = "front_app_switched" ]; then
  # sketchybar --set $NAME label="$INFO" icon.background.image="app.$INFO" # original_icon + name
  # sketchybar --set $NAME label="$INFO" icon="$($CONFIG_DIR/plugins/icon_map.sh "$INFO")" # icon + name
  sketchybar --set $NAME icon="$($CONFIG_DIR/plugins/icon_map.sh "$INFO")" icon.color=$BLUE # icon
fi
