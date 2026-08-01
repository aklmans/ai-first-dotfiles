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

# The speaker glyph is the icon, and nothing else. It used to be the icon here
# and the label as well - items/volume.sh set icon=$VOLUME_100 while
# plugins/volume.sh set label=$ICON on every volume change - so the chip drew
# two speakers, the second in a 25pt slot that made it wider than the rest of
# the row. Every other item on this side reads the same way: glyph in the icon,
# text in the label.
volume_icon=(
  click_script="$PLUGIN_DIR/volume_click.sh"
  icon=$VOLUME_100
  icon.color=$BAR_COLOR
  icon.padding_left=10
  icon.padding_right=10
  icon.font="$FONT:Regular:$THEME_FONT_SIZE_ICON"
  label.drawing=off
  # No background of its own: the bracket below draws one pill around this and
  # the slider, and a second one here put two rounded rectangles and two borders
  # in the same place. That is what made this chip the odd one out in a row that
  # is otherwise uniform.
  background.drawing=off
)

status_bracket=(
	background.height=$THEME_ITEM_HEIGHT
	background.corner_radius=$THEME_PILL_CORNER_RADIUS
	background.padding_right=5
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
