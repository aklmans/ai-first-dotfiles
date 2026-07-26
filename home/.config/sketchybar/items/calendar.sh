#!/bin/bash

calendar=(
  icon=􀐫
  icon.color=$BAR_COLOR
	icon.padding_left=10
  label.color=$BAR_COLOR
  align=center
	background.height=$THEME_ITEM_HEIGHT
	background.corner_radius=$THEME_PILL_CORNER_RADIUS
	background.padding_right=5
	background.border_width=$THEME_ITEM_BORDER_WIDTH
	background.border_color=$BAR_COLOR
	background.color=$THEME_ACCENT_CALENDAR
  padding_left=5
  update_freq=30
  script="$PLUGIN_DIR/calendar.sh"
)

sketchybar --add item calendar right       \
           --set calendar "${calendar[@]}" \
           --subscribe calendar system_woke
