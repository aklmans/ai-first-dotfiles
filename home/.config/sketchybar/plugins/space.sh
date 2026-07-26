#!/usr/bin/env bash

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/lib/runtime.sh"

AEROSPACE="${AEROSPACE:-$(sketchybar_runtime_bin "" aerospace)}"
UPDATER="$CONFIG_DIR/plugins/aerospace_spaces_refresh.sh"

set_space_label() {
  sketchybar --set "$NAME" icon="$*"
}

# Renaming a chip is a SketchyBar operation and keeps working on its own;
# switching to a workspace and moving a window into one are AeroSpace's, and
# say so once instead of failing silently.
require_aerospace() {
  if sketchybar_runtime_has "$AEROSPACE"; then
    return 0
  fi

  sketchybar_warn_once aerospace-missing \
    'aerospace CLI not found; clicking a workspace chip cannot switch workspaces.'
  return 1
}

mouse_clicked() {
  workspace="${NAME#space.}"

  if [ "$BUTTON" = "right" ]; then
    require_aerospace &&
      "$AEROSPACE" move-node-to-workspace --focus-follows-window "$workspace" 2>/dev/null || true
  elif [ "$MODIFIER" = "shift" ]; then
    SPACE_LABEL="$(osascript -e "return (text returned of (display dialog \"Give a name to workspace $workspace:\" default answer \"\" with icon note buttons {\"Cancel\", \"Continue\"} default button \"Continue\"))")"
    if [ $? -eq 0 ]; then
      if [ "$SPACE_LABEL" = "" ]; then
        set_space_label "$workspace"
      else
        set_space_label "$workspace ($SPACE_LABEL)"
      fi
    fi
  else
    require_aerospace && "$AEROSPACE" workspace "$workspace" 2>/dev/null || true
  fi

  [ -x "$UPDATER" ] && "$UPDATER" >/dev/null 2>&1 || true
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked ;;
esac
