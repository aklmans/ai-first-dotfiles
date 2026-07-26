#!/bin/bash

volume_slider=(
  script="$PLUGIN_DIR/volume.sh"
  updates=on
  label.drawing=off
  icon.drawing=on
  icon.color=$BLACK
  slider.highlight_color=$THEME_ACCENT_BAR_BORDER
  slider.background.height=5
  slider.background.corner_radius=3
  slider.background.color=$THEME_ACCENT_VOLUME
  slider.knob=􀀁
  slider.knob.drawing=on
)

volume_icon=(
  click_script="$PLUGIN_DIR/volume_click.sh"
  padding_left=10
  icon=$VOLUME_100
  icon.color=$BAR_COLOR
  label.color=$BAR_COLOR
  icon.width=0
  icon.align=left
  icon.font="$FONT:Regular:$THEME_FONT_SIZE_ICON"
  label.width=25
  label.align=left
  label.font="$FONT:Regular:$THEME_FONT_SIZE_ICON"
 	background.height=$THEME_ITEM_HEIGHT
	background.corner_radius=$THEME_PILL_CORNER_RADIUS
	background.padding_right=5
	background.border_width=$THEME_ITEM_BORDER_WIDTH
	background.border_color=$BAR_COLOR
	background.color=$THEME_ACCENT_VOLUME
	background.drawing=on
)

status_bracket=(
 	background.height=$THEME_ITEM_HEIGHT
	background.corner_radius=$THEME_PILL_CORNER_RADIUS
	background.border_width=$THEME_ITEM_BORDER_WIDTH
	background.border_color=$BAR_COLOR
	background.color=$THEME_ACCENT_VOLUME
)

sketchybar --add slider volume right            \
           --set volume "${volume_slider[@]}"   \
           --subscribe volume volume_change     \
                              mouse.clicked     \
                                                \
           --add item volume_icon right         \
           --set volume_icon "${volume_icon[@]}"

sketchybar --add bracket status volume volume_icon \
           --set status "${status_bracket[@]}"
