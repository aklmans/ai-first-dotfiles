#!/usr/bin/env bash

AEROSPACE="${AEROSPACE:-/opt/homebrew/bin/aerospace}"
UPDATER="${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/aerospace_spaces_refresh.sh"

set_space_label() {
  sketchybar --set "$NAME" icon="$*"
}

mouse_clicked() {
  workspace="${NAME#space.}"

  if [ "$BUTTON" = "right" ]; then
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
    "$AEROSPACE" workspace "$workspace" 2>/dev/null || true
  fi

  "$UPDATER" >/dev/null 2>&1 || true
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked ;;
esac
