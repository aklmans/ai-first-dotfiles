#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SKETCHYBAR="${SKETCHYBAR:-/opt/homebrew/bin/sketchybar}"
JQ="${JQ:-/opt/homebrew/bin/jq}"
SQLITE="${SQLITE:-/usr/bin/sqlite3}"
STATE_DIR="${AI_ATTENTION_STATE_DIR:-$HOME/Library/Caches/sketchybar}"
STATE_FILE="$STATE_DIR/ai_attention.json"
LOCK_DIR="$STATE_FILE.lock"
POLL_STAMP="$STATE_DIR/ai_attention.last_poll"
REQUEST_DIR="$STATE_DIR/ai_attention.clear_requests"
NOTIFICATION_DB="${NOTIFICATION_DB:-$HOME/Library/Group Containers/group.com.apple.usernoted/db2/db}"
ACTION="${1:-update}"

source "$CONFIG_DIR/lib/theme.sh"
source "$CONFIG_DIR/icons.sh"

app_item() {
  case "$1" in
    warp) printf 'ai_notify.warp' ;;
    codex) printf 'ai_notify.codex' ;;
    idea) printf 'ai_notify.idea' ;;
    goland) printf 'ai_notify.goland' ;;
    *) return 1 ;;
  esac
}

popup_item() {
  case "$1" in
    warp) printf 'ai_notify.popup.warp' ;;
    codex) printf 'ai_notify.popup.codex' ;;
    idea) printf 'ai_notify.popup.idea' ;;
    goland) printf 'ai_notify.popup.goland' ;;
    *) return 1 ;;
  esac
}

app_label() {
  case "$1" in
    warp) printf 'Warp' ;;
    codex) printf 'Codex' ;;
    idea) printf 'IntelliJ IDEA' ;;
    goland) printf 'GoLand' ;;
    *) return 1 ;;
  esac
}

app_icon_name() {
  case "$1" in
    warp) printf 'Warp' ;;
    codex) printf 'Codex' ;;
    idea) printf 'IntelliJ IDEA' ;;
    goland) printf 'GoLand' ;;
    *) return 1 ;;
  esac
}

app_bundle() {
  case "$1" in
    warp) printf 'dev.warp.Warp-Stable' ;;
    codex) printf 'com.openai.codex' ;;
    idea) printf 'com.jetbrains.intellij' ;;
    goland) printf 'com.jetbrains.goland' ;;
    *) return 1 ;;
  esac
}

app_fallback() {
  case "$1" in
    warp) printf 'Warp' ;;
    codex) printf 'Codex' ;;
    idea) printf 'IntelliJ IDEA' ;;
    goland) printf 'GoLand' ;;
    *) return 1 ;;
  esac
}

ensure_state() {
  /bin/mkdir -p "$STATE_DIR"
  if [ ! -f "$STATE_FILE" ]; then
    /usr/bin/printf '{"version":1,"apps":{}}\n' > "$STATE_FILE"
  fi
}

known_app() {
  case "$1" in
    warp|codex|idea|goland) return 0 ;;
    *) return 1 ;;
  esac
}

lock_state() {
  local _ lock_mtime now
  for _ in {1..50}; do
    if /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
      return 0
    fi

    if [ -d "$LOCK_DIR" ]; then
      lock_mtime="$(/usr/bin/stat -f %m "$LOCK_DIR" 2>/dev/null || printf '0')"
      now="$(/bin/date +%s)"
      if [ "$lock_mtime" -gt 0 ] && [ $((now - lock_mtime)) -gt 10 ]; then
        /bin/rmdir "$LOCK_DIR" 2>/dev/null || true
      fi
    fi

    /bin/sleep 0.05
  done
  return 1
}

unlock_state() {
  /bin/rmdir "$LOCK_DIR" 2>/dev/null || true
}

valid_count() {
  case "${1:-}" in
    ''|*[!0-9]*) printf '1' ;;
    *) printf '%s' "$1" ;;
  esac
}

state_count() {
  local app="$1"
  ensure_state
  "$JQ" -r --arg app "$app" '.apps[$app].count // 0 | tonumber' "$STATE_FILE" 2>/dev/null || printf '0'
}

state_title() {
  local app="$1"
  ensure_state
  "$JQ" -r --arg app "$app" '.apps[$app].title // ""' "$STATE_FILE" 2>/dev/null || true
}

dismissed_at() {
  local app="$1"
  ensure_state
  "$JQ" -r --arg app "$app" '.dismissed[$app] // 0 | tonumber' "$STATE_FILE" 2>/dev/null || printf '0'
}

macos_notification_condition() {
  case "$1" in
    warp)
      printf "lower(a.identifier) in ('dev.warp.warp-stable','dev.warp.warp-preview')"
      ;;
    chatgpt)
      printf "lower(a.identifier) in ('com.openai.chat')"
      ;;
    codex)
      printf "lower(a.identifier) in ('com.openai.codex')"
      ;;
    idea)
      printf "lower(a.identifier) in ('com.jetbrains.intellij')"
      ;;
    goland)
      printf "lower(a.identifier) in ('com.jetbrains.goland')"
      ;;
    *)
      return 1
      ;;
  esac
}

macos_notification_stats() {
  local app="$1"
  local dismissed condition timestamp_expr

  [ -r "$NOTIFICATION_DB" ] || return 1
  [ -x "$SQLITE" ] || return 1

  dismissed="$(dismissed_at "$app")"
  condition="$(macos_notification_condition "$app")"
  timestamp_expr='coalesce(r.delivered_date, r.request_last_date, r.request_date, 0)'

  "$SQLITE" -readonly "$NOTIFICATION_DB" "
    select count(r.rec_id) || '|' || coalesce(max($timestamp_expr), 0)
    from app a
    join record r on r.app_id = a.app_id
    where ($condition) and $timestamp_expr > $dismissed;
  " 2>/dev/null
}

latest_macos_notification_time() {
  local app="$1"
  local condition timestamp_expr

  [ -r "$NOTIFICATION_DB" ] || {
    printf '0'
    return 0
  }
  [ -x "$SQLITE" ] || {
    printf '0'
    return 0
  }

  condition="$(macos_notification_condition "$app")"
  timestamp_expr='coalesce(r.delivered_date, r.request_last_date, r.request_date, 0)'

  "$SQLITE" -readonly "$NOTIFICATION_DB" "
    select coalesce(max($timestamp_expr), 0)
    from app a
    join record r on r.app_id = a.app_id
    where ($condition);
  " 2>/dev/null || printf '0'
}

sync_macos_notifications() {
  local app stats count latest title now tmp next

  ensure_state
  process_clear_requests
  [ -r "$NOTIFICATION_DB" ] || return 0
  [ -x "$SQLITE" ] || return 0

  lock_state || return 1
  trap 'unlock_state' EXIT
  tmp="$(/usr/bin/mktemp "${STATE_FILE}.XXXXXX")"
  "$JQ" '
    del(.apps.chatgpt, .apps.atlas, .apps.gemini)
    | del(.dismissed.chatgpt, .dismissed.atlas, .dismissed.gemini)
  ' "$STATE_FILE" > "$tmp"
  now="$(/bin/date +%s)"

  for app in warp codex idea goland; do
    stats="$(macos_notification_stats "$app" || true)"
    [ -n "$stats" ] || continue

    IFS='|' read -r count latest <<<"$stats"
    count="$(valid_count "$count")"
    latest="${latest:-0}"

    next="$(/usr/bin/mktemp "${STATE_FILE}.XXXXXX")"
    if [ "$count" -gt 0 ]; then
      if [ "$count" -eq 1 ]; then
        title="$(app_label "$app") macOS notification"
      else
        title="$(app_label "$app") $count macOS notifications"
      fi
      "$JQ" \
        --arg app "$app" \
        --arg title "$title" \
        --argjson count "$count" \
        --argjson latest "$latest" \
        --argjson updated_at "$now" \
        '.version = 1 | .apps[$app] = {
          count: $count,
          title: $title,
          source: "macos",
          latest: $latest,
          updated_at: $updated_at
        }' "$tmp" > "$next"
    else
      "$JQ" --arg app "$app" '
        if (.apps[$app].source // "") == "macos" then
          del(.apps[$app])
        else
          .
        end
      ' "$tmp" > "$next"
    fi
    /bin/mv "$next" "$tmp"
  done

  /bin/mv "$tmp" "$STATE_FILE"
  unlock_state
  trap - EXIT
}

maybe_update() {
  local now last
  ensure_state
  now="$(/bin/date +%s)"
  last="$(/bin/cat "$POLL_STAMP" 2>/dev/null || printf '0')"

  case "$last" in
    ''|*[!0-9]*) last=0 ;;
  esac

  [ $((now - last)) -lt 3 ] && return 0
  /usr/bin/printf '%s\n' "$now" > "$POLL_STAMP"
  sync_macos_notifications
  update_bar
}

mark_app() {
  local app="$1"
  local count title tmp
  count="$(valid_count "${2:-1}")"
  shift 2 || true
  title="${*:-$(app_label "$app") needs attention}"
  ensure_state
  lock_state || return 1
  trap 'unlock_state' EXIT
  tmp="$(/usr/bin/mktemp "${STATE_FILE}.XXXXXX")"
  "$JQ" \
    --arg app "$app" \
    --arg title "$title" \
    --arg source "${AI_ATTENTION_SOURCE:-manual}" \
    --argjson count "$count" \
    --argjson updated_at "$(/bin/date +%s)" \
    '.version = 1 | .apps[$app] = {
      count: $count,
      title: $title,
      source: $source,
      updated_at: $updated_at
    }' "$STATE_FILE" > "$tmp"
  /bin/mv "$tmp" "$STATE_FILE"
  unlock_state
  trap - EXIT
}

clear_app() {
  local app="$1"
  local tmp latest
  ensure_state
  latest="$(latest_macos_notification_time "$app")"
  lock_state || return 1
  trap 'unlock_state' EXIT
  tmp="$(/usr/bin/mktemp "${STATE_FILE}.XXXXXX")"
  "$JQ" \
    --arg app "$app" \
    --argjson latest "${latest:-0}" \
    'del(.apps[$app]) | .dismissed[$app] = $latest' \
    "$STATE_FILE" > "$tmp"
  /bin/mv "$tmp" "$STATE_FILE"
  unlock_state
  trap - EXIT
}

request_clear_app() {
  local app="$1"
  known_app "$app" || return 64
  /bin/mkdir -p "$REQUEST_DIR"
  /usr/bin/printf '%s\n' "$(/bin/date +%s)" > "$REQUEST_DIR/$app"
}

process_clear_requests() {
  local request app

  [ -d "$REQUEST_DIR" ] || return 0

  for request in "$REQUEST_DIR"/*; do
    [ -e "$request" ] || continue
    app="${request##*/}"
    if known_app "$app"; then
      clear_app "$app" || true
    fi
    /bin/rm -f "$request"
  done
}

clear_all() {
  local warp_latest codex_latest idea_latest goland_latest
  ensure_state
  warp_latest="$(latest_macos_notification_time warp)"
  codex_latest="$(latest_macos_notification_time codex)"
  idea_latest="$(latest_macos_notification_time idea)"
  goland_latest="$(latest_macos_notification_time goland)"
  lock_state || return 1
  trap 'unlock_state' EXIT
  "$JQ" -n \
    --argjson warp "${warp_latest:-0}" \
    --argjson codex "${codex_latest:-0}" \
    --argjson idea "${idea_latest:-0}" \
    --argjson goland "${goland_latest:-0}" \
    '{
      version: 1,
      apps: {},
      dismissed: {
        warp: $warp,
        codex: $codex,
        idea: $idea,
        goland: $goland
      }
    }' > "$STATE_FILE"
  unlock_state
  trap - EXIT
}

set_item_state() {
  local app="$1"
  local count="$2"
  local item icon
  item="$(app_item "$app")"
  icon="$("$CONFIG_DIR/plugins/icon_map.sh" "$(app_icon_name "$app")")"

  if [ "${count:-0}" -gt 0 ]; then
    "$SKETCHYBAR" --set "$item" \
      icon="$icon" \
      icon.color=$THEME_ACCENT_ATTENTION \
      label="$count" \
      label.drawing=on \
      label.width=18 \
      label.color=$THEME_ACCENT_ON_ACCENT \
      drawing=off \
      background.drawing=off >/dev/null 2>&1 || true
  else
    "$SKETCHYBAR" --set "$item" \
      icon="$icon" \
      icon.color=$THEME_ACCENT_MUTED \
      label.drawing=off \
      label.width=0 \
      label.color=$BAR_COLOR \
      drawing=off \
      background.drawing=off >/dev/null 2>&1 || true
  fi
}

set_popup_state() {
  local app="$1"
  local count="$2"
  local item icon label title
  item="$(popup_item "$app")"
  icon="$("$CONFIG_DIR/plugins/icon_map.sh" "$(app_icon_name "$app")")"
  label="$(app_label "$app")"
  title="$(state_title "$app")"

  if [ "${count:-0}" -gt 0 ]; then
    if [ -n "$title" ] && [ "$title" != "null" ]; then
      label="$label  $count  $title"
    else
      label="$label  $count"
    fi
    "$SKETCHYBAR" --set "$item" \
      drawing=on \
      icon="$icon" \
      icon.color=$THEME_ACCENT_ATTENTION \
      label="$label" \
      label.color=$THEME_ACCENT_ON_ACCENT >/dev/null 2>&1 || true
  else
    "$SKETCHYBAR" --set "$item" drawing=off >/dev/null 2>&1 || true
  fi
}

append_app_args() {
  local app="$1"
  local count="$2"
  local item popup icon label title

  item="$(app_item "$app")"
  popup="$(popup_item "$app")"
  icon="$("$CONFIG_DIR/plugins/icon_map.sh" "$(app_icon_name "$app")")"

  if [ "${count:-0}" -gt 0 ]; then
    args+=(--set "$item" \
      icon="$icon" \
      icon.font="$THEME_FONT_BADGE_APP_ICON" \
      icon.color=$THEME_ACCENT_ATTENTION \
      icon.padding_left=8 \
      icon.padding_right=4 \
      label="$count" \
      label.drawing=on \
      label.font="$THEME_FONT_BADGE" \
      label.width=18 \
      label.color=$THEME_ACCENT_ON_ACCENT \
      label.padding_left=1 \
      label.padding_right=8 \
      drawing=on \
      background.drawing=off)

    label="$(app_label "$app")"
    title="$(state_title "$app")"
    if [ -n "$title" ] && [ "$title" != "null" ]; then
      label="$label  $count  $title"
    else
      label="$label  $count"
    fi
    args+=(--set "$popup" \
      drawing=on \
      icon="$icon" \
      icon.color=$THEME_ACCENT_ATTENTION \
      label="$label" \
      label.color=$THEME_ACCENT_ON_ACCENT)
  else
    args+=(--set "$item" \
      icon="$icon" \
      icon.color=$THEME_ACCENT_MUTED \
      label.drawing=off \
      label.width=0 \
      label.color=$BAR_COLOR \
      drawing=off \
      background.drawing=off)
    args+=(--set "$popup" drawing=off)
  fi
}

update_bar() {
  local warp_count codex_count idea_count goland_count
  local total active_apps
  local args=()

  warp_count="$(state_count warp)"
  codex_count="$(state_count codex)"
  idea_count="$(state_count idea)"
  goland_count="$(state_count goland)"

  total=$((warp_count + codex_count + idea_count + goland_count))
  active_apps=0
  [ "$warp_count" -gt 0 ] && active_apps=$((active_apps + 1))
  [ "$codex_count" -gt 0 ] && active_apps=$((active_apps + 1))
  [ "$idea_count" -gt 0 ] && active_apps=$((active_apps + 1))
  [ "$goland_count" -gt 0 ] && active_apps=$((active_apps + 1))

  append_app_args warp "$warp_count"
  append_app_args codex "$codex_count"
  append_app_args idea "$idea_count"
  append_app_args goland "$goland_count"

  if [ "$active_apps" -eq 0 ]; then
    args+=(--set ai_notify.total \
      drawing=on \
      icon=$BELL \
      icon.font="$THEME_FONT_BADGE_ICON" \
      icon.color=$THEME_ACCENT_MUTED \
      icon.padding_left=8 \
      icon.padding_right=4 \
      label=0 \
      label.drawing=on \
      label.font="$THEME_FONT_BADGE" \
      label.width=18 \
      label.color=$THEME_ACCENT_ON_ACCENT \
      label.padding_left=1 \
      label.padding_right=8)
    args+=(--set ai_notify.popup.empty \
      drawing=on \
      icon=$BELL \
      icon.color=$THEME_ACCENT_MUTED \
      label="No AI attention" \
      label.color=$THEME_ACCENT_MUTED)
  elif [ "$active_apps" -eq 1 ]; then
    args+=(--set ai_notify.total drawing=off popup.drawing=off)
    args+=(--set ai_notify.popup.empty drawing=off)
  else
    args+=(--set ai_notify.total \
      drawing=on \
      icon=$BELL_DOT \
      icon.font="$THEME_FONT_BADGE_ICON" \
      icon.color=$THEME_ACCENT_ATTENTION \
      icon.padding_left=8 \
      icon.padding_right=4 \
      label="$total" \
      label.drawing=on \
      label.font="$THEME_FONT_BADGE" \
      label.width=18 \
      label.color=$THEME_ACCENT_ON_ACCENT \
      label.padding_left=1 \
      label.padding_right=8)
    args+=(--set ai_notify.popup.empty drawing=off)
  fi

  "$SKETCHYBAR" -m "${args[@]}" >/dev/null 2>&1 || true
}

reveal_app() {
  local app="$1"
  clear_app "$app"
  update_bar
  "$HOME/.config/aerospace/reveal-app.sh" "$(app_bundle "$app")" "$(app_fallback "$app")" >/dev/null 2>&1 || true
}

case "$ACTION" in
  request-clear)
    request_clear_app "${2:?missing app}"
    ;;
  sync-state|sync)
    sync_macos_notifications
    ;;
  paint|render)
    update_bar
    ;;
  update|routine|forced|system_woke)
    sync_macos_notifications
    update_bar
    ;;
  mark)
    mark_app "${2:?missing app}" "${3:-1}" "${@:4}"
    update_bar
    ;;
  clear)
    clear_app "${2:?missing app}"
    sync_macos_notifications
    update_bar
    ;;
  clear-all)
    clear_all
    sync_macos_notifications
    update_bar
    ;;
  reveal)
    reveal_app "${2:?missing app}"
    ;;
  toggle-popup)
    sync_macos_notifications
    update_bar
    "$SKETCHYBAR" --set ai_notify.total popup.drawing=toggle >/dev/null 2>&1 || true
    ;;
  open-center)
    sync_macos_notifications
    update_bar
    "$SKETCHYBAR" --set ai_notify.total popup.drawing=toggle >/dev/null 2>&1 || true
    ;;
  maybe-update)
    maybe_update
    ;;
  *)
    update_bar
    ;;
esac
