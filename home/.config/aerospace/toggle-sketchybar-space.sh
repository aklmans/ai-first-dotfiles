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
SKETCHYBAR_CONFIG_DIR="${SKETCHYBAR_CONFIG_DIR:-$HOME_DIR/.config/sketchybar}"

# shellcheck source=lib/layout.sh
source "$SCRIPT_DIR/lib/layout.sh"
# SketchyBar is optional: this runs from .aerospace.toml's after-startup-command,
# so a missing resolver must degrade rather than fail the whole login.
if [ -r "$SKETCHYBAR_CONFIG_DIR/lib/display-resolver.sh" ]; then
  source "$SKETCHYBAR_CONFIG_DIR/lib/display-resolver.sh"
else
  sketchybar_display_id_for_monitor() { return 1; }
  sketchybar_visible_display_list_excluding() { printf 'all\n'; }
fi

aerospace_layout_load_config
aerospace_layout_resolve

# Whichever display currently plays the main role, not whichever display the
# author owns. On a single-display Mac this is that display, which is what
# makes Option+Shift+Space - the shortcut the README leads with - do something
# there instead of failing to resolve a monitor name.
MAIN_MONITOR_NAME="${SKETCHYBAR_HIDE_MONITOR_NAME:-$(aerospace_layout_resolved_name main)}"

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

# Rewrites only the [gaps] table, between its markers.
#
# Two things used to go wrong here. The monitor names were a fixed list of the
# author's three displays, so every login rewrote a stranger's config with
# display names that machine has never seen. And the block boundary was "the
# next line starting with [", which swallowed the comment lines that sit
# between [gaps] and the app-rule section - including the anchor comment that
# render-app-rules.sh and doctor.sh both key off, so one press of
# Option+Shift+Space quietly broke app-rule rendering.
#
# Now: markers delimit the block, and a monitor is named only in the one
# profile that treats displays differently.

path = pathlib.Path(sys.argv[1])
profile = sys.argv[2]
main_monitor_name = sys.argv[3]

BEGIN = "# >>> managed by toggle-sketchybar-space.sh - outer gaps >>>"
END = "# <<< managed by toggle-sketchybar-space.sh - outer gaps <<<"

if profile not in {"normal", "compact", "main-compact"}:
    raise SystemExit(f"unknown profile: {profile}")

side_fallback = 8 if profile == "compact" else 20
top_fallback = 8 if profile == "compact" else 95

def gap_lines(key, fallback):
    # Every display shares one value except when only the main display is
    # compacted, so the common case needs no monitor names at all.
    if profile != "main-compact" or not main_monitor_name:
        return [f"    {key} = {fallback}\n"]

    escaped = main_monitor_name.replace("\\", "\\\\").replace('"', '\\"')
    return [
        f"    {key} = [\n",
        f'        {{ monitor."{escaped}" = 8 }},\n',
        f"        {fallback}\n",
        "    ]\n",
    ]

profile_lines = [
    "[gaps]\n",
    "    inner.horizontal = 8\n",
    "    inner.vertical = 8\n",
    *gap_lines("outer.left", side_fallback),
    *gap_lines("outer.bottom", side_fallback),
    *gap_lines("outer.top", top_fallback),
    *gap_lines("outer.right", side_fallback),
]

lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
begin_index = None
end_index = None

for index, line in enumerate(lines):
    stripped = line.rstrip("\n")
    if stripped == BEGIN and begin_index is None:
        begin_index = index
    elif stripped == END and begin_index is not None:
        end_index = index
        break

if begin_index is not None and end_index is not None:
    new_lines = lines[: begin_index + 1] + profile_lines + lines[end_index:]
else:
    # A config from before the markers existed. Find the table the old way,
    # then hand back the trailing blank and comment lines that belong to
    # whatever comes next, and write the markers so this only happens once.
    start = None
    for index, line in enumerate(lines):
        if line.strip() == "[gaps]":
            start = index
            break

    if start is None:
        raise SystemExit("[gaps] block not found in AeroSpace config")

    end = len(lines)
    for close_index in range(start + 1, len(lines)):
        if lines[close_index].startswith("["):
            end = close_index
            break

    while end - 1 > start:
        candidate = lines[end - 1].strip()
        if candidate == "" or candidate.startswith("#"):
            end -= 1
            continue
        break

    new_lines = (
        lines[:start]
        + [BEGIN + "\n"]
        + profile_lines
        + [END + "\n"]
        + lines[end:]
    )

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

  # With one display, "the main display" and "the bar" are the same thing. The
  # per-display path below would ask SketchyBar to keep the bar visible on
  # every display except the only one, which SketchyBar reads as "all", so the
  # bar would stay put and the shortcut would appear to do nothing.
  if [ "${AEROSPACE_MONITOR_COUNT:-0}" -le 1 ]; then
    set_bar_hidden "$value"
    return 0
  fi

  main_display_id="${SKETCHYBAR_HIDE_DISPLAY_ID:-$(sketchybar_display_id_for_monitor "$MAIN_MONITOR_NAME" || true)}"
  if [ -z "$main_display_id" ]; then
    # Hammerspoon or SketchyBar could not map the monitor to an arrangement id.
    # Hiding the whole bar is the honest reading of "hide the bar on my main
    # screen" when the screens cannot be told apart, and beats refusing.
    printf 'Unable to resolve SketchyBar display id for monitor "%s"; hiding the whole bar instead.\n' \
      "$MAIN_MONITOR_NAME" >&2
    set_bar_hidden "$value"
    return 0
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
