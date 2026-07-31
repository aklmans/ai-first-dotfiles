#!/usr/bin/env bash
# Shared, data-only user preference layer.
#
# Runtime modules remain useful without this file: the defaults below reproduce
# the repository's long-standing full behavior. Named presets install a
# profile.conf next to this library to turn optional surfaces off or choose a
# different workspace/terminal layout without editing implementation files.

AI_FIRST_CONFIG_DIR="${AI_FIRST_CONFIG_DIR:-$HOME/.config/ai-first}"
AI_FIRST_PROFILE_PATH="${AI_FIRST_PROFILE_PATH:-$AI_FIRST_CONFIG_DIR/profile.conf}"

ai_first_profile_apply_file() {
  local profile_file="$1"
  local line key value
  local assignment_re='^([A-Z0-9_]+)="([^"$`]*)"[[:space:]]*$'

  [ -r "$profile_file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ $assignment_re ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      case "$key" in
        AI_FIRST_PRESET) [ -n "$env_preset_set" ] || AI_FIRST_PRESET="$value" ;;
        AI_FIRST_APP_ROUTING) [ -n "$env_app_routing_set" ] || AI_FIRST_APP_ROUTING="$value" ;;
        AI_FIRST_FEATURE_AI_HOTKEYS) [ -n "$env_ai_hotkeys_set" ] || AI_FIRST_FEATURE_AI_HOTKEYS="$value" ;;
        AI_FIRST_FEATURE_NOTIFICATIONS) [ -n "$env_notifications_set" ] || AI_FIRST_FEATURE_NOTIFICATIONS="$value" ;;
        AI_FIRST_FEATURE_RECORDING) [ -n "$env_recording_set" ] || AI_FIRST_FEATURE_RECORDING="$value" ;;
        AI_FIRST_BAR_LEFT_ITEMS) [ -n "$env_bar_left_set" ] || AI_FIRST_BAR_LEFT_ITEMS="$value" ;;
        AI_FIRST_BAR_CENTER_ITEMS) [ -n "$env_bar_center_set" ] || AI_FIRST_BAR_CENTER_ITEMS="$value" ;;
        AI_FIRST_BAR_RIGHT_ITEMS) [ -n "$env_bar_right_set" ] || AI_FIRST_BAR_RIGHT_ITEMS="$value" ;;
        AI_FIRST_NOTIFICATION_APPS) [ -n "$env_notification_apps_set" ] || AI_FIRST_NOTIFICATION_APPS="$value" ;;
        AI_FIRST_TERMINAL_APP) [ -n "$env_terminal_set" ] || AI_FIRST_TERMINAL_APP="$value" ;;
        AI_FIRST_ADD_BAR_RIGHT_ITEMS) [ -n "$env_add_bar_right_set" ] || AI_FIRST_ADD_BAR_RIGHT_ITEMS="$value" ;;
        AEROSPACE_MAIN_MONITOR_NAME) [ -n "$env_main_monitor_set" ] || AEROSPACE_MAIN_MONITOR_NAME="$value" ;;
        AEROSPACE_SIDE_MONITOR_NAME) [ -n "$env_side_monitor_set" ] || AEROSPACE_SIDE_MONITOR_NAME="$value" ;;
        AEROSPACE_STAGE_MONITOR_NAME) [ -n "$env_stage_monitor_set" ] || AEROSPACE_STAGE_MONITOR_NAME="$value" ;;
        AEROSPACE_MAIN_WORKSPACES) [ -n "$env_main_workspaces_set" ] || AEROSPACE_MAIN_WORKSPACES="$value" ;;
        AEROSPACE_SIDE_WORKSPACES) [ -n "$env_side_workspaces_set" ] || AEROSPACE_SIDE_WORKSPACES="$value" ;;
        AEROSPACE_STAGE_WORKSPACES) [ -n "$env_stage_workspaces_set" ] || AEROSPACE_STAGE_WORKSPACES="$value" ;;
      esac
    fi
  done < "$profile_file"
}

ai_first_profile_load() {
  [ "${AI_FIRST_PROFILE_LOADED:-0}" != "1" ] || return 0

  local env_preset_set="${AI_FIRST_PRESET+x}"
  local env_app_routing_set="${AI_FIRST_APP_ROUTING+x}"
  local env_ai_hotkeys_set="${AI_FIRST_FEATURE_AI_HOTKEYS+x}"
  local env_notifications_set="${AI_FIRST_FEATURE_NOTIFICATIONS+x}"
  local env_recording_set="${AI_FIRST_FEATURE_RECORDING+x}"
  local env_bar_left_set="${AI_FIRST_BAR_LEFT_ITEMS+x}"
  local env_bar_center_set="${AI_FIRST_BAR_CENTER_ITEMS+x}"
  local env_bar_right_set="${AI_FIRST_BAR_RIGHT_ITEMS+x}"
  local env_notification_apps_set="${AI_FIRST_NOTIFICATION_APPS+x}"
  local env_terminal_set="${AI_FIRST_TERMINAL_APP+x}"
  local env_add_bar_right_set="${AI_FIRST_ADD_BAR_RIGHT_ITEMS+x}"
  local env_main_monitor_set="${AEROSPACE_MAIN_MONITOR_NAME+x}"
  local env_side_monitor_set="${AEROSPACE_SIDE_MONITOR_NAME+x}"
  local env_stage_monitor_set="${AEROSPACE_STAGE_MONITOR_NAME+x}"
  local env_main_workspaces_set="${AEROSPACE_MAIN_WORKSPACES+x}"
  local env_side_workspaces_set="${AEROSPACE_SIDE_WORKSPACES+x}"
  local env_stage_workspaces_set="${AEROSPACE_STAGE_WORKSPACES+x}"

  # layout.sh first loads its shipped .conf files, then asks this profile to
  # override them, and finally restores true process-environment overrides. Its
  # intermediate values are not user environment choices.
  if [ "${AI_FIRST_PROFILE_OVERRIDE_AEROSPACE:-0}" = "1" ]; then
    env_main_monitor_set=''
    env_side_monitor_set=''
    env_stage_monitor_set=''
    env_main_workspaces_set=''
    env_side_workspaces_set=''
    env_stage_workspaces_set=''
  fi

  AI_FIRST_PRESET="${AI_FIRST_PRESET-custom}"
  AI_FIRST_APP_ROUTING="${AI_FIRST_APP_ROUTING-1}"
  AI_FIRST_FEATURE_AI_HOTKEYS="${AI_FIRST_FEATURE_AI_HOTKEYS-1}"
  AI_FIRST_FEATURE_NOTIFICATIONS="${AI_FIRST_FEATURE_NOTIFICATIONS-1}"
  AI_FIRST_FEATURE_RECORDING="${AI_FIRST_FEATURE_RECORDING-1}"
  AI_FIRST_BAR_LEFT_ITEMS="${AI_FIRST_BAR_LEFT_ITEMS-apple spaces aerospace_layout front_app}"
  AI_FIRST_BAR_CENTER_ITEMS="${AI_FIRST_BAR_CENTER_ITEMS-spotify media}"
  AI_FIRST_BAR_RIGHT_ITEMS="${AI_FIRST_BAR_RIGHT_ITEMS-clock calendar ai_notifications battery volume}"
  AI_FIRST_NOTIFICATION_APPS="${AI_FIRST_NOTIFICATION_APPS-warp codex idea goland}"
  AI_FIRST_TERMINAL_APP="${AI_FIRST_TERMINAL_APP-Warp}"
  AI_FIRST_ADD_BAR_RIGHT_ITEMS="${AI_FIRST_ADD_BAR_RIGHT_ITEMS-}"

  # Parse, do not source: profile files are data and cannot execute commands.
  # The active preset chooses one overlay scope, so switching presets does not
  # accidentally reactivate module choices made under another starting point.
  ai_first_profile_apply_file "$AI_FIRST_PROFILE_PATH"
  local profile_file overlay_dir
  overlay_dir="$AI_FIRST_CONFIG_DIR/modules/$AI_FIRST_PRESET"
  for profile_file in "$overlay_dir"/*.conf; do
    ai_first_profile_apply_file "$profile_file"
  done

  local item
  for item in $AI_FIRST_ADD_BAR_RIGHT_ITEMS; do
    case " $AI_FIRST_BAR_RIGHT_ITEMS " in
      *" $item "*) ;;
      *) AI_FIRST_BAR_RIGHT_ITEMS="${AI_FIRST_BAR_RIGHT_ITEMS:+$AI_FIRST_BAR_RIGHT_ITEMS }$item" ;;
    esac
  done

  AI_FIRST_PROFILE_LOADED=1
  export AI_FIRST_PRESET AI_FIRST_APP_ROUTING
  export AI_FIRST_FEATURE_AI_HOTKEYS AI_FIRST_FEATURE_NOTIFICATIONS
  export AI_FIRST_FEATURE_RECORDING AI_FIRST_BAR_LEFT_ITEMS
  export AI_FIRST_BAR_CENTER_ITEMS AI_FIRST_BAR_RIGHT_ITEMS
  export AI_FIRST_NOTIFICATION_APPS AI_FIRST_TERMINAL_APP
  export AI_FIRST_ADD_BAR_RIGHT_ITEMS
  export AEROSPACE_MAIN_MONITOR_NAME AEROSPACE_SIDE_MONITOR_NAME AEROSPACE_STAGE_MONITOR_NAME
  export AEROSPACE_MAIN_WORKSPACES AEROSPACE_SIDE_WORKSPACES AEROSPACE_STAGE_WORKSPACES
}

ai_first_enabled() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON|enabled|ENABLED)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ai_first_profile_load
