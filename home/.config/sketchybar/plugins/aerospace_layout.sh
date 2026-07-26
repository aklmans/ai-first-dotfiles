#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/lib/runtime.sh"

AEROSPACE="${AEROSPACE:-$(sketchybar_runtime_bin "" aerospace)}"

# The item shows the layout of the focused window. Without AeroSpace there is
# no layout to show, so the honest thing is to leave the item empty rather than
# report a state nothing produced.
if ! sketchybar_runtime_has "$AEROSPACE"; then
  sketchybar_warn_once aerospace-missing \
    'aerospace CLI not found; the layout indicator stays hidden.'
  sketchybar -m --set "${NAME:-aerospace_layout}" icon.width=0 label.width=0 >/dev/null 2>&1 || true
  exit 0
fi

run_aerospace() {
  local timeout="${AEROSPACE_QUERY_TIMEOUT_SECONDS:-2}"
  local output_file pid watcher status
  output_file="$(mktemp "${TMPDIR:-/tmp}/sketchybar-aerospace.XXXXXX")"

  "$AEROSPACE" "$@" >"$output_file" 2>/dev/null &
  pid=$!

  (
    sleep "$timeout"
    kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null
  ) &
  watcher=$!

  status=0
  wait "$pid" || status=$?
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true

  if [ "$status" -eq 0 ]; then
    cat "$output_file"
  fi
  rm -f "$output_file"
  return "$status"
}

window_state() {
  source "$CONFIG_DIR/lib/theme.sh"
  source "$CONFIG_DIR/icons.sh"

  WINDOW="$(run_aerospace list-windows --focused --format "%{window-layout}%{tab}%{window-parent-container-layout}%{tab}%{workspace-root-container-layout}%{tab}%{window-is-fullscreen}" || true)"

  COLOR=$BAR_BORDER_COLOR
  ICON=""
  LABEL=""

  if [ -n "$WINDOW" ]; then
    IFS=$'\t' read -r WINDOW_LAYOUT PARENT_LAYOUT ROOT_LAYOUT IS_FULLSCREEN <<<"$WINDOW"

    if [ "$IS_FULLSCREEN" = "true" ] || [[ "$WINDOW_LAYOUT" == *fullscreen* ]]; then
      ICON=$YABAI_FULLSCREEN_ZOOM
      COLOR=$GREEN
    elif [ "$WINDOW_LAYOUT" = "floating" ]; then
      ICON=$YABAI_FLOAT
      COLOR=$RED
    elif [[ "$PARENT_LAYOUT" == *accordion* || "$ROOT_LAYOUT" == *accordion* ]]; then
      ICON=$YABAI_STACK
      LABEL="ACC"
      COLOR=$MAGENTA
    fi
  fi

  args=(--animate sin 10 --set "$NAME" icon.color=$COLOR)

  [ -z "$LABEL" ] && args+=(label.width=0) \
                  || args+=(label="$LABEL" label.width=36)

  [ -z "$ICON" ] && args+=(icon.width=0) \
                 || args+=(icon="$ICON" icon.width=30)

  sketchybar -m "${args[@]}"
}

mouse_clicked() {
  run_aerospace layout floating tiling >/dev/null || true
  window_state
}

case "${SENDER:-}" in
  "mouse.clicked") mouse_clicked ;;
  *) window_state ;;
esac
