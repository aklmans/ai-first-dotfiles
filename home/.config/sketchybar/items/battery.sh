#!/bin/bash

power=(
	icon.color=$BAR_COLOR
	icon.padding_left=10
	label.color=$BAR_COLOR
  align=center
	background.height=$THEME_ITEM_HEIGHT
	background.corner_radius=$THEME_PILL_CORNER_RADIUS
	background.padding_right=5
	background.border_width=$THEME_ITEM_BORDER_WIDTH
	background.border_color=$BAR_COLOR
	background.color=$THEME_ACCENT_BATTERY
  update_freq=120
	script="$PLUGIN_DIR/battery.sh"
)


sketchybar --add item battery right \
           --set battery "${power[@]}" \
           --subscribe battery system_woke power_source_change



