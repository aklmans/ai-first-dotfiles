#!/bin/bash

volume_slider=(
  script="$PLUGIN_DIR/volume.sh"
  updates=on
  label.drawing=off
  icon.drawing=on
  icon.color=$BLACK
  slider.highlight_color=$BLUE
  slider.background.height=5
  slider.background.corner_radius=3
  slider.background.color=$GREEN
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
  icon.font="$FONT:Regular:14.0"
  label.width=25
  label.align=left
  label.font="$FONT:Regular:14.0"
 	background.height=26
	background.corner_radius=20
	background.padding_right=5
	background.border_width=$BORDER_WIDTH
	background.border_color=$BAR_COLOR
	background.color=$GREEN
	background.drawing=on
)

status_bracket=(
 	background.height=26
	background.corner_radius=20
	background.border_width=$BORDER_WIDTH
	background.border_color=$BAR_COLOR
	background.color=$GREEN
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
