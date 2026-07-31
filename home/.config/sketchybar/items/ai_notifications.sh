#!/usr/bin/env bash

source "$CONFIG_DIR/lib/notifications.sh"

ai_total=(
  icon=$BELL_DOT
  icon.font="$THEME_FONT_BADGE_ICON"
  icon.color=$THEME_ACCENT_MUTED
  icon.padding_left=8
  icon.padding_right=4
  label.drawing=off
  label.font="$THEME_FONT_BADGE"
  label.color=$THEME_ACCENT_ON_ACCENT
  label.padding_left=1
  label.padding_right=8
  padding_left=3
  padding_right=3
  background.drawing=off
  popup.align=right
  click_script="$PLUGIN_DIR/ai_app_notifications.sh toggle-popup"
)

ai_app_common=(
  icon.font="$THEME_FONT_BADGE_APP_ICON"
  icon.color=$THEME_ACCENT_MUTED
  icon.padding_left=8
  icon.padding_right=4
  label.drawing=off
  label.font="$THEME_FONT_BADGE"
  label.color=$THEME_ACCENT_ON_ACCENT
  label.padding_left=1
  label.padding_right=8
  padding_left=3
  padding_right=3
  background.drawing=off
)

ai_popup_common=(
  drawing=off
  icon.font="$THEME_FONT_APP_ICON"
  icon.color=$THEME_ACCENT_MUTED
  icon.padding_left=8
  icon.padding_right=8
  label.font="$THEME_FONT_POPUP"
  label.color=$THEME_ACCENT_ON_ACCENT
  label.padding_left=0
  label.padding_right=12
  background.corner_radius=8
  background.height=$THEME_ITEM_HEIGHT
)

sketchybar --add event ai_notification_sync

sketchybar --add item ai_notify.sync right             \
           --set ai_notify.sync                        \
             drawing=off                               \
             updates=on                                \
             update_freq=5                             \
             script="$PLUGIN_DIR/ai_app_notifications.sh sync-state" \
           --subscribe ai_notify.sync system_woke      \
                                     ai_notification_sync

sketchybar --add item ai_notify.total right             \
           --set ai_notify.total "${ai_total[@]}"       \
           --subscribe ai_notify.total system_woke      \
                                            mouse.clicked

ai_notification_items=(ai_notify.total)
while IFS= read -r app; do
  [ -n "$app" ] || continue
  label="$(ai_first_notification_label "$app")"
  sketchybar --add item "ai_notify.$app" right \
             --set "ai_notify.$app" "${ai_app_common[@]}" \
                  icon="$("$PLUGIN_DIR/icon_map.sh" "$label")" \
                  click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal $app" \
             --subscribe "ai_notify.$app" system_woke mouse.clicked
  ai_notification_items+=("ai_notify.$app")
done < <(ai_first_notification_apps)

sketchybar --add item ai_notify.popup.empty popup.ai_notify.total \
           --set ai_notify.popup.empty "${ai_popup_common[@]}" \
                icon=$BELL \
                label="No AI attention"

while IFS= read -r app; do
  [ -n "$app" ] || continue
  label="$(ai_first_notification_label "$app")"
  sketchybar --add item "ai_notify.popup.$app" popup.ai_notify.total \
             --set "ai_notify.popup.$app" "${ai_popup_common[@]}" \
                  icon="$("$PLUGIN_DIR/icon_map.sh" "$label")" \
                  click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal $app"
done < <(ai_first_notification_apps)

sketchybar --add bracket ai_notify.bracket              \
             "${ai_notification_items[@]}"              \
           --set ai_notify.bracket                      \
             background.drawing=on                      \
             background.height=$THEME_ITEM_HEIGHT                       \
             background.corner_radius=14                \
             background.color=$BACKGROUND_1             \
             background.border_color=$BACKGROUND_2      \
             background.border_width=$THEME_ITEM_BORDER_WIDTH
