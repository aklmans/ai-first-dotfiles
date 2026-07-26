#!/bin/bash

clock=(
  icon=􀐫
  icon.padding_left=10
  icon.color=$BAR_COLOR
  label.color=$BAR_COLOR
  label.padding_right=5
  label.width=78
  align=center
	background.height=$THEME_ITEM_HEIGHT
	background.corner_radius=$THEME_PILL_CORNER_RADIUS
	background.padding_right=5
	background.border_width=$THEME_ITEM_BORDER_WIDTH
	background.border_color=$BAR_COLOR
  background.color=$THEME_ACCENT_CLOCK
  update_freq=1
  script="$PLUGIN_DIR/clock.sh"
  # click_script="$PLUGIN_DIR/zen.sh"
)

sketchybar --add item clock right       \
           --set clock "${clock[@]}"
