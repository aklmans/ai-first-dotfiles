#!/usr/bin/env bash
set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"

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

mode="${1:-toggle}"

bar_hidden() {
  "$SKETCHYBAR_BIN" --query bar 2>/dev/null |
    /usr/bin/awk -F'"' '/"hidden"/ { print $4; exit }'
}

rewrite_outer_top() {
  local profile="$1"
  /usr/bin/python3 - "$AEROSPACE_CONFIG" "$profile" "$MAIN_MONITOR_NAME" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
profile = sys.argv[2]
main_monitor_name = sys.argv[3]

def monitor_top(name, value):
    escaped = name.replace("\\", "\\\\").replace('"', '\\"')
    return f'        {{ monitor."{escaped}" = {value} }},\n'

profiles = {
    "normal": [
        "    outer.top = [\n",
        '        { monitor."Built-in Retina Display" = 95 },\n',
        '        { monitor."24V5C2" = 95 },\n',
        '        { monitor."PHL 279C9" = 95 },\n',
        "        95\n",
        "    ]\n",
    ],
    "compact": [
        "    outer.top = [\n",
        '        { monitor."Built-in Retina Display" = 20 },\n',
        '        { monitor."24V5C2" = 20 },\n',
        '        { monitor."PHL 279C9" = 20 },\n',
        "        20\n",
        "    ]\n",
    ],
    "main-compact": [
        "    outer.top = [\n",
        monitor_top("Built-in Retina Display", 20 if main_monitor_name == "Built-in Retina Display" else 95),
        monitor_top("24V5C2", 20 if main_monitor_name == "24V5C2" else 95),
        monitor_top("PHL 279C9", 20 if main_monitor_name == "PHL 279C9" else 95),
        "        95\n",
        "    ]\n",
    ],
}

if profile not in profiles:
    raise SystemExit(f"unknown profile: {profile}")

lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
start = None
end = None

for index, line in enumerate(lines):
    if line.strip() == "outer.top = [":
        start = index
        depth = 0
        for close_index in range(index, len(lines)):
            depth += lines[close_index].count("[")
            depth -= lines[close_index].count("]")
            if close_index > index and depth <= 0:
                end = close_index
                break
        break

if start is None or end is None:
    raise SystemExit("outer.top block not found in AeroSpace config")

new_lines = lines[:start] + profiles[profile] + lines[end + 1 :]
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

main_display_ids() {
  "$AEROSPACE_BIN" list-monitors --format '%{monitor-name}	%{monitor-appkit-nsscreen-screens-id}' 2>/dev/null |
    /usr/bin/awk -F '\t' -v name="$MAIN_MONITOR_NAME" '$1 == name { print $2; exit }'
}

visible_display_list_without_main() {
  local main_display_id="$1"
  local displays_json

  displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null)"
  /usr/bin/python3 - "$main_display_id" "$displays_json" <<'PY'
import json
import sys

target = sys.argv[1]
payload = sys.argv[2]
try:
    displays = json.loads(payload)
except json.JSONDecodeError:
    raise SystemExit(1)

visible = [
    str(display.get("arrangement-id"))
    for display in displays
    if str(display.get("arrangement-id")) != target
]

if not visible:
    visible = ["all"]

print(",".join(visible))
PY
}

set_bar_main_hidden() {
  local value="$1"
  local main_display_id visible_displays

  main_display_id="${SKETCHYBAR_HIDE_DISPLAY_ID:-$(main_display_ids || true)}"
  if [ -z "$main_display_id" ]; then
    main_display_id="1"
  fi

  if [ "$value" = "on" ]; then
    visible_displays="$(visible_display_list_without_main "$main_display_id")"
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
  rewrite_outer_top compact
  reload_aerospace
  set_bar_hidden on
  save_mode hide
elif [ "$mode" = "hide-main" ]; then
  rewrite_outer_top main-compact
  reload_aerospace
  set_bar_main_hidden on
  save_mode main-hide
elif [ "$mode" = "show-main" ]; then
  rewrite_outer_top normal
  reload_aerospace
  set_bar_main_hidden off
  save_mode show
else
  rewrite_outer_top normal
  reload_aerospace
  set_bar_hidden off
  save_mode show
fi
