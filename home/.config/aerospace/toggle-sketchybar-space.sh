#!/usr/bin/env bash
set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
INFERRED_HOME=""
case "$SCRIPT_DIR" in
  */.config/aerospace)
    INFERRED_HOME="${SCRIPT_DIR%/.config/aerospace}"
    ;;
esac

HOME_DIR="${HOME:-$INFERRED_HOME}"
if [ ! -f "$HOME_DIR/.aerospace.toml" ] && [ -n "$INFERRED_HOME" ]; then
  HOME_DIR="$INFERRED_HOME"
fi

AEROSPACE_CONFIG="${AEROSPACE_CONFIG:-$HOME_DIR/.aerospace.toml}"
STATE_DIR="${STATE_DIR:-$HOME_DIR/.config/aerospace/state}"
STATE_FILE="${STATE_FILE:-$STATE_DIR/sketchybar-space-mode}"
MAIN_MONITOR_NAME="${SKETCHYBAR_HIDE_MONITOR_NAME:-PHL 279C9}"
SKETCHYBAR_CONFIG_DIR="${SKETCHYBAR_CONFIG_DIR:-$HOME_DIR/.config/sketchybar}"

source "$SKETCHYBAR_CONFIG_DIR/lib/display-resolver.sh"

mode="${1:-toggle}"

bar_hidden() {
  "$SKETCHYBAR_BIN" --query bar 2>/dev/null |
    /usr/bin/awk -F'"' '/"hidden"/ { print $4; exit }'
}

rewrite_outer_gaps() {
  local profile="$1"
  /usr/bin/python3 - "$AEROSPACE_CONFIG" "$profile" "$MAIN_MONITOR_NAME" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
profile = sys.argv[2]
main_monitor_name = sys.argv[3]
monitor_names = ["Built-in Retina Display", "24V5C2", "PHL 279C9"]

def monitor_gap(name, value):
    escaped = name.replace("\\", "\\\\").replace('"', '\\"')
    return f'        {{ monitor."{escaped}" = {value} }},\n'

def side_value(name):
    if profile == "compact":
        return 8
    if profile == "main-compact" and name == main_monitor_name:
        return 8
    return 20

def top_value(name):
    if profile == "compact":
        return 8
    if profile == "main-compact" and name == main_monitor_name:
        return 8
    return 95

def gap_lines(key, values, fallback):
    return (
        [f"    {key} = [\n"]
        + [monitor_gap(name, values(name)) for name in monitor_names]
        + [f"        {fallback}\n", "    ]\n"]
    )

if profile not in {"normal", "compact", "main-compact"}:
    raise SystemExit(f"unknown profile: {profile}")

side_fallback = 8 if profile == "compact" else 20
top_fallback = 8 if profile == "compact" else 95
profile_lines = [
    "[gaps]\n",
    "    inner.horizontal = 8\n",
    "    inner.vertical = 8\n",
    *gap_lines("outer.left", side_value, side_fallback),
    *gap_lines("outer.bottom", side_value, side_fallback),
    *gap_lines("outer.top", top_value, top_fallback),
    *gap_lines("outer.right", side_value, side_fallback),
    "\n",
]

lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
start = None
end = None

for index, line in enumerate(lines):
    if line.strip() == "[gaps]":
        start = index
        end = len(lines)
        for close_index in range(index + 1, len(lines)):
            if lines[close_index].startswith("["):
                end = close_index
                break
        break

if start is None:
    raise SystemExit("[gaps] block not found in AeroSpace config")

new_lines = lines[:start] + profile_lines + lines[end:]
if new_lines != lines:
    path.write_text("".join(new_lines), encoding="utf-8")
PY
}

reload_aerospace() {
  local attempt

  for attempt in $(/usr/bin/seq 1 10); do
    if "$AEROSPACE_BIN" reload-config --dry-run --no-gui >/dev/null 2>&1; then
      break
    fi
    /bin/sleep 0.15
  done

  "$AEROSPACE_BIN" reload-config --dry-run --no-gui >/dev/null

  for attempt in $(/usr/bin/seq 1 10); do
    if "$AEROSPACE_BIN" reload-config >/dev/null 2>&1; then
      break
    fi
    /bin/sleep 0.15
  done

  "$AEROSPACE_BIN" reload-config >/dev/null
  "$AEROSPACE_BIN" balance-sizes >/dev/null 2>&1 || true
}

set_bar_hidden() {
  local value="$1"
  local attempt

  for attempt in $(/usr/bin/seq 1 20); do
    if "$SKETCHYBAR_BIN" --bar hidden="$value" display=all >/dev/null 2>&1; then
      return 0
    fi
    /bin/sleep 0.1
  done

  return 0
}

set_bar_main_hidden() {
  local value="$1"
  local main_display_id visible_displays

  main_display_id="${SKETCHYBAR_HIDE_DISPLAY_ID:-$(sketchybar_display_id_for_monitor "$MAIN_MONITOR_NAME" || true)}"
  if [ -z "$main_display_id" ]; then
    printf 'Unable to resolve SketchyBar display id for monitor: %s\n' "$MAIN_MONITOR_NAME" >&2
    return 1
  fi

  if [ "$value" = "on" ]; then
    visible_displays="$(sketchybar_visible_display_list_excluding "$main_display_id")"
    "$SKETCHYBAR_BIN" --bar hidden=off display="$visible_displays" >/dev/null
  else
    "$SKETCHYBAR_BIN" --bar hidden=off display=all >/dev/null
  fi
}

save_mode() {
  /bin/mkdir -p "$STATE_DIR"
  /usr/bin/printf '%s\n' "$1" >"$STATE_FILE"
}

case "$mode" in
  toggle)
    if [ -r "$STATE_FILE" ] && [ "$(/usr/bin/head -n 1 "$STATE_FILE")" = "main-hide" ]; then
      mode="show-main"
    else
      mode="hide-main"
    fi
    ;;
  apply)
    if [ -r "$STATE_FILE" ]; then
      mode="$(/usr/bin/head -n 1 "$STATE_FILE")"
    else
      mode="show"
    fi
    ;;
  hide|show|hide-main|show-main|main-hide|main-show|toggle-main)
    ;;
  *)
    printf 'usage: %s [toggle|hide|show|hide-main|show-main|toggle-main|apply]\n' "$0" >&2
    exit 64
    ;;
esac

case "$mode" in
  toggle-main)
    if [ -r "$STATE_FILE" ] && [ "$(/usr/bin/head -n 1 "$STATE_FILE")" = "main-hide" ]; then
      mode="show-main"
    else
      mode="hide-main"
    fi
    ;;
  main-hide)
    mode="hide-main"
    ;;
  main-show)
    mode="show-main"
    ;;
esac

if [ "$mode" = "hide" ]; then
  rewrite_outer_gaps compact
  reload_aerospace
  set_bar_hidden on
  save_mode hide
elif [ "$mode" = "hide-main" ]; then
  rewrite_outer_gaps main-compact
  reload_aerospace
  set_bar_main_hidden on
  save_mode main-hide
elif [ "$mode" = "show-main" ]; then
  rewrite_outer_gaps normal
  reload_aerospace
  set_bar_main_hidden off
  save_mode show
else
  rewrite_outer_gaps normal
  reload_aerospace
  set_bar_hidden off
  save_mode show
fi
