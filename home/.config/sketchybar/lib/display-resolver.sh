#!/usr/bin/env bash

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"

screen_info_for_monitor() {
  local monitor_name="$1"

  "$HS_BIN" -c 'for _, screen in ipairs(hs.screen.allScreens()) do print(screen:name() .. "\t" .. screen:id() .. "\t" .. screen:getUUID()) end' 2>/dev/null |
    /usr/bin/awk -F '\t' -v name="$monitor_name" '$1 == name { print $2 "\t" $3; exit }'
}

sketchybar_display_id_for_monitor() {
  local monitor_name="$1"
  local screen_info direct_display_id screen_uuid displays_json display_id

  screen_info="$(screen_info_for_monitor "$monitor_name" || true)"
  [ -n "$screen_info" ] || return 1

  direct_display_id="$(/usr/bin/printf '%s\n' "$screen_info" | /usr/bin/awk -F '\t' '{ print $1; exit }')"
  screen_uuid="$(/usr/bin/printf '%s\n' "$screen_info" | /usr/bin/awk -F '\t' '{ print $2; exit }')"
  displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null || true)"

  display_id="$(/usr/bin/python3 - "$direct_display_id" "$screen_uuid" "$displays_json" <<'PY' || true
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

  [ -n "$display_id" ] || return 1
  /usr/bin/printf '%s\n' "$display_id"
}

sketchybar_visible_display_list_excluding() {
  local hidden_display_id="$1"
  local displays_json

  displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null || true)"
  /usr/bin/python3 - "$hidden_display_id" "$displays_json" <<'PY'
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
