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

mode="${1:-toggle}"

bar_hidden() {
  "$SKETCHYBAR_BIN" --query bar 2>/dev/null |
    /usr/bin/awk -F'"' '/"hidden"/ { print $4; exit }'
}

rewrite_outer_top() {
  local profile="$1"
  /usr/bin/python3 - "$AEROSPACE_CONFIG" "$profile" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
profile = sys.argv[2]

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
  "$AEROSPACE_BIN" reload-config --dry-run --no-gui >/dev/null
  "$AEROSPACE_BIN" reload-config >/dev/null
  "$AEROSPACE_BIN" balance-sizes >/dev/null 2>&1 || true
}

set_bar_hidden() {
  local value="$1"
  local attempt

  for attempt in $(/usr/bin/seq 1 20); do
    if "$SKETCHYBAR_BIN" --bar hidden="$value" >/dev/null 2>&1; then
      return 0
    fi
    /bin/sleep 0.1
  done

  return 0
}

save_mode() {
  /bin/mkdir -p "$STATE_DIR"
  /usr/bin/printf '%s\n' "$1" >"$STATE_FILE"
}

case "$mode" in
  toggle)
    current_hidden="$(bar_hidden || true)"
    if [ "$current_hidden" = "on" ]; then
      mode="show"
    else
      mode="hide"
    fi
    ;;
  apply)
    if [ -r "$STATE_FILE" ]; then
      mode="$(/usr/bin/head -n 1 "$STATE_FILE")"
    else
      mode="show"
    fi
    ;;
  hide|show)
    ;;
  *)
    printf 'usage: %s [toggle|hide|show|apply]\n' "$0" >&2
    exit 64
    ;;
esac

if [ "$mode" = "hide" ]; then
  rewrite_outer_top compact
  reload_aerospace
  set_bar_hidden on
  save_mode hide
else
  rewrite_outer_top normal
  reload_aerospace
  set_bar_hidden off
  save_mode show
fi
