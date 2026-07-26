#!/usr/bin/env bash
# Maps a monitor name onto the display id SketchyBar uses for `display=`.
#
# The precise route is Hammerspoon: `hs` reports every screen's DirectDisplayID
# and UUID, and `sketchybar --query displays` reports the same identifiers
# alongside its own arrangement-id. Matching on identity is what stops the
# 24-inch and 27-inch bars swapping when macOS renumbers displays after a lid
# open or a reconnect.
#
# Hammerspoon is optional, though. Wanting tiled windows without a status bar,
# or a status bar without a Lua runtime, are both reasonable, and this file used
# to call `hs` unconditionally and hand back an empty string when it was not
# there. An empty answer here is indistinguishable from "that monitor is not
# connected", so the bar quietly bound its workspace items to the wrong display
# and looked like it was working. Now there is a fallback and, whenever the
# fallback is used, a line saying so.
#
# Library: defines functions, runs nothing on source. Safe under
# `set -euo pipefail`; AeroSpace's toggle-sketchybar-space.sh sources it.

SKETCHYBAR_DISPLAY_LIB_DIR="${BASH_SOURCE[0]%/*}"
[ "$SKETCHYBAR_DISPLAY_LIB_DIR" != "${BASH_SOURCE[0]}" ] || SKETCHYBAR_DISPLAY_LIB_DIR="."

if [ -r "$SKETCHYBAR_DISPLAY_LIB_DIR/runtime.sh" ]; then
  # shellcheck source=runtime.sh
  . "$SKETCHYBAR_DISPLAY_LIB_DIR/runtime.sh"
fi

# A caller that named a binary keeps that binary, exactly as before: AeroSpace's
# toggle script sets all three and then uses them itself, so resolving them out
# from under it would be a new way to break the thing this file is fixing. Only
# an unset variable is looked up, and only then does the Apple-silicon Homebrew
# path stop being the first guess - an Intel Mac installs to /usr/local/bin.
if [ -z "${SKETCHYBAR_BIN:-}" ] && type sketchybar_runtime_bin >/dev/null 2>&1; then
  SKETCHYBAR_BIN="$(sketchybar_runtime_bin "" sketchybar)"
fi
if [ -z "${HS_BIN:-}" ] && type sketchybar_runtime_bin >/dev/null 2>&1; then
  HS_BIN="$(sketchybar_runtime_bin "" hs)"
fi
if [ -z "${AEROSPACE_BIN:-}" ] && type sketchybar_runtime_bin >/dev/null 2>&1; then
  AEROSPACE_BIN="$(sketchybar_runtime_bin "${AEROSPACE:-}" aerospace)"
fi
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"
AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"

sketchybar_display_warn() {
  if type sketchybar_warn_once >/dev/null 2>&1; then
    sketchybar_warn_once "$@"
    return 0
  fi

  shift || true
  printf 'sketchybar: %s\n' "$*" >&2
}

# "<DirectDisplayID>\t<UUID>" for a monitor, via Hammerspoon. Empty when
# Hammerspoon is not installed or does not know that name.
screen_info_for_monitor() {
  local monitor_name="$1"

  [ -n "${HS_BIN:-}" ] && [ -x "$HS_BIN" ] || return 1

  "$HS_BIN" -c 'for _, screen in ipairs(hs.screen.allScreens()) do print(screen:name() .. "\t" .. screen:id() .. "\t" .. screen:getUUID()) end' 2>/dev/null |
    /usr/bin/awk -F '\t' -v name="$monitor_name" '$1 == name { print $2 "\t" $3; exit }'
}

# AeroSpace's own view of the displays, used when Hammerspoon is absent.
# AeroSpace numbers monitors in the same left-to-right order macOS arranges
# them, so its monitor-id is usually SketchyBar's arrangement-id - usually,
# which is why taking this route always prints a warning.
aerospace_display_id_for_monitor() {
  local monitor_name="$1"
  local monitor_id

  [ -n "${AEROSPACE_BIN:-}" ] && [ -x "$AEROSPACE_BIN" ] || return 1
  [ -n "$monitor_name" ] || return 1

  monitor_id="$("$AEROSPACE_BIN" list-monitors --format "%{monitor-id}$(printf '\t')%{monitor-name}" 2>/dev/null |
    /usr/bin/awk -F '\t' -v name="$monitor_name" '$2 == name { print $1; exit }')"

  [ -n "$monitor_id" ] || return 1
  printf '%s\n' "$monitor_id"
}

# Resolves a monitor into SKETCHYBAR_DISPLAY_ID rather than onto stdout.
#
# Callers that want the answer *and* the warning have to use this form: a
# command substitution is a subshell, so the "warn once" guard set inside one
# never reaches the caller, and three roles resolved that way produced three
# copies of the same sentence at every bar load.
SKETCHYBAR_DISPLAY_ID="${SKETCHYBAR_DISPLAY_ID:-}"
sketchybar_display_id_for_monitor_var() {
  local monitor_name="$1"
  local screen_info direct_display_id screen_uuid displays_json display_id

  SKETCHYBAR_DISPLAY_ID=""
  [ -n "$monitor_name" ] || return 1

  if ! { [ -n "${HS_BIN:-}" ] && [ -x "$HS_BIN" ]; }; then
    sketchybar_display_warn hs-missing \
      "Hammerspoon CLI (hs) not found; resolving displays through aerospace instead. Display identity cannot be verified, so bar items may land on the wrong screen after a display is renumbered."
    SKETCHYBAR_DISPLAY_ID="$(aerospace_display_id_for_monitor "$monitor_name" || true)"
    [ -n "$SKETCHYBAR_DISPLAY_ID" ] || return 1
    return 0
  fi

  screen_info="$(screen_info_for_monitor "$monitor_name" || true)"
  if [ -z "$screen_info" ]; then
    # Hammerspoon answered but does not know that monitor. That is either a
    # disconnected display or a name only AeroSpace uses; ask AeroSpace before
    # giving up, and say which route produced the answer.
    if display_id="$(aerospace_display_id_for_monitor "$monitor_name")"; then
      sketchybar_display_warn "hs-unknown-$monitor_name" \
        "Hammerspoon does not report a screen named \"$monitor_name\"; using the aerospace monitor order instead."
      SKETCHYBAR_DISPLAY_ID="$display_id"
      return 0
    fi
    return 1
  fi

  [ -x "$PYTHON_BIN" ] || {
    sketchybar_display_warn python-missing \
      "python3 not found at $PYTHON_BIN; falling back to the aerospace monitor order for display ids."
    SKETCHYBAR_DISPLAY_ID="$(aerospace_display_id_for_monitor "$monitor_name" || true)"
    [ -n "$SKETCHYBAR_DISPLAY_ID" ] || return 1
    return 0
  }

  direct_display_id="$(/usr/bin/printf '%s\n' "$screen_info" | /usr/bin/awk -F '\t' '{ print $1; exit }')"
  screen_uuid="$(/usr/bin/printf '%s\n' "$screen_info" | /usr/bin/awk -F '\t' '{ print $2; exit }')"
  displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null || true)"

  display_id="$("$PYTHON_BIN" - "$direct_display_id" "$screen_uuid" "$displays_json" <<'PY' || true
import json
import sys

direct_display_id = sys.argv[1]
screen_uuid = sys.argv[2]
payload = sys.argv[3]

try:
    displays = json.loads(payload)
except json.JSONDecodeError:
    raise SystemExit(0)

for display in displays:
    if str(display.get("UUID")) == screen_uuid or str(display.get("DirectDisplayID")) == direct_display_id:
        print(display.get("arrangement-id"))
        break
PY
)"

  if [ -z "$display_id" ]; then
    # SketchyBar is not running yet, or reports no display matching that
    # screen. AeroSpace may still know the monitor.
    if display_id="$(aerospace_display_id_for_monitor "$monitor_name")"; then
      sketchybar_display_warn "sketchybar-unmatched-$monitor_name" \
        "SketchyBar reports no display matching \"$monitor_name\"; using the aerospace monitor order instead."
      SKETCHYBAR_DISPLAY_ID="$display_id"
      return 0
    fi
    return 1
  fi

  SKETCHYBAR_DISPLAY_ID="$display_id"
}

# Printing form, kept because AeroSpace's toggle-sketchybar-space.sh calls it.
sketchybar_display_id_for_monitor() {
  sketchybar_display_id_for_monitor_var "$1" || return 1
  /usr/bin/printf '%s\n' "$SKETCHYBAR_DISPLAY_ID"
}

sketchybar_visible_display_list_excluding() {
  local hidden_display_id="$1"
  local displays_json

  if ! { [ -n "${SKETCHYBAR_BIN:-}" ] && [ -x "$SKETCHYBAR_BIN" ]; } || [ ! -x "$PYTHON_BIN" ]; then
    # Without a way to enumerate displays, "every display except that one" can
    # only honestly be answered with "all". The caller hides the whole bar,
    # which is a visible outcome rather than a silent no-op.
    sketchybar_display_warn display-list \
      "cannot enumerate displays (sketchybar or python3 missing); treating the request as every display."
    printf 'all\n'
    return 0
  fi

  displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null || true)"
  "$PYTHON_BIN" - "$hidden_display_id" "$displays_json" <<'PY'
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
