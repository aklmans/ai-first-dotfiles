#!/usr/bin/env bash

# Notification support is intentionally a whitelist. The plugin knows how to
# read macOS notifications and reveal exactly these four applications; a
# profile may choose any subset without pretending arbitrary apps are supported.

_ai_first_profile_lib="${AI_FIRST_PROFILE_LIB:-$HOME/.config/ai-first/lib/profile.sh}"
if [ -r "$_ai_first_profile_lib" ]; then
  # shellcheck source=/dev/null
  source "$_ai_first_profile_lib"
fi

AI_FIRST_NOTIFICATION_APPS="${AI_FIRST_NOTIFICATION_APPS-warp codex idea goland}"

ai_first_notification_supported() {
  case "${1:-}" in
    warp|codex|idea|goland) return 0 ;;
    *) return 1 ;;
  esac
}

ai_first_notification_enabled() {
  local needle="${1:-}"
  local app

  ai_first_notification_supported "$needle" || return 1
  for app in $AI_FIRST_NOTIFICATION_APPS; do
    [ "$app" = "$needle" ] && return 0
  done
  return 1
}

ai_first_notification_apps() {
  local app

  for app in $AI_FIRST_NOTIFICATION_APPS; do
    ai_first_notification_supported "$app" && printf '%s\n' "$app"
  done
}

ai_first_notification_label() {
  case "${1:-}" in
    warp) printf 'Warp' ;;
    codex) printf 'Codex' ;;
    idea) printf 'IntelliJ IDEA' ;;
    goland) printf 'GoLand' ;;
    *) return 1 ;;
  esac
}
