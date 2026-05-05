#!/usr/bin/env bash

ai_total=(
  icon=$BELL_DOT
  icon.font="$FONT:Semibold:13.5"
  icon.color=$GREY
  icon.padding_left=8
  icon.padding_right=4
  label.drawing=off
  label.font="$FONT:Semibold:14.0"
  label.color=$WHITE
  label.padding_left=1
  label.padding_right=8
  padding_left=3
  padding_right=3
  background.drawing=off
  popup.align=right
  click_script="$PLUGIN_DIR/ai_app_notifications.sh toggle-popup"
)

ai_app_common=(
  icon.font="sketchybar-app-font:Regular:15.0"
  icon.color=$GREY
  icon.padding_left=8
  icon.padding_right=4
  label.drawing=off
  label.font="$FONT:Semibold:14.0"
  label.color=$WHITE
  label.padding_left=1
  label.padding_right=8
  padding_left=3
  padding_right=3
  background.drawing=off
)

ai_popup_common=(
  drawing=off
  icon.font="sketchybar-app-font:Regular:16.0"
  icon.color=$GREY
  icon.padding_left=8
  icon.padding_right=8
  label.font="$FONT:Semibold:12.0"
  label.color=$WHITE
  label.padding_left=0
  label.padding_right=12
  background.corner_radius=8
  background.height=26
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

sketchybar --add item ai_notify.warp right              \
           --set ai_notify.warp "${ai_app_common[@]}"   \
                icon="$("$PLUGIN_DIR/icon_map.sh" "Warp")" \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal warp" \
           --subscribe ai_notify.warp system_woke       \
                                           mouse.clicked \
                                                        \
           --add item ai_notify.codex right             \
           --set ai_notify.codex "${ai_app_common[@]}"  \
                icon="$("$PLUGIN_DIR/icon_map.sh" "Codex")" \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal codex" \
           --subscribe ai_notify.codex system_woke      \
                                            mouse.clicked \
                                                        \
           --add item ai_notify.idea right              \
           --set ai_notify.idea "${ai_app_common[@]}"   \
                icon="$("$PLUGIN_DIR/icon_map.sh" "IntelliJ IDEA")" \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal idea" \
           --subscribe ai_notify.idea system_woke       \
                                            mouse.clicked \
                                                        \
           --add item ai_notify.goland right            \
           --set ai_notify.goland "${ai_app_common[@]}" \
                icon="$("$PLUGIN_DIR/icon_map.sh" "GoLand")" \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal goland" \
           --subscribe ai_notify.goland system_woke     \
                                             mouse.clicked

sketchybar --add item ai_notify.popup.empty popup.ai_notify.total       \
           --set ai_notify.popup.empty "${ai_popup_common[@]}"          \
                icon=$BELL                                              \
                label="No AI attention"                                 \
                                                        \
           --add item ai_notify.popup.warp popup.ai_notify.total        \
           --set ai_notify.popup.warp "${ai_popup_common[@]}"           \
                icon="$("$PLUGIN_DIR/icon_map.sh" "Warp")"              \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal warp" \
                                                        \
           --add item ai_notify.popup.codex popup.ai_notify.total       \
           --set ai_notify.popup.codex "${ai_popup_common[@]}"          \
                icon="$("$PLUGIN_DIR/icon_map.sh" "Codex")"             \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal codex" \
                                                        \
           --add item ai_notify.popup.idea popup.ai_notify.total        \
           --set ai_notify.popup.idea "${ai_popup_common[@]}"           \
                icon="$("$PLUGIN_DIR/icon_map.sh" "IntelliJ IDEA")"     \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal idea" \
                                                        \
           --add item ai_notify.popup.goland popup.ai_notify.total      \
           --set ai_notify.popup.goland "${ai_popup_common[@]}"         \
                icon="$("$PLUGIN_DIR/icon_map.sh" "GoLand")"            \
                click_script="$PLUGIN_DIR/ai_app_notifications.sh reveal goland"

sketchybar --add bracket ai_notify.bracket              \
             ai_notify.total                            \
             ai_notify.warp                             \
             ai_notify.codex                            \
             ai_notify.idea                             \
             ai_notify.goland                           \
           --set ai_notify.bracket                      \
             background.drawing=on                      \
             background.height=26                       \
             background.corner_radius=14                \
             background.color=$BACKGROUND_1             \
             background.border_color=$BACKGROUND_2      \
             background.border_width=2
