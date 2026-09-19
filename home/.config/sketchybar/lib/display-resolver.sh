#!/usr/bin/env bash
# SketchyBar arrangement IDs are not AeroSpace monitor IDs or hs screen order.
# Only correlate an unambiguous Hammerspoon screen identity with a live
# SketchyBar display. Missing identity means unknown, never a guessed number.
SKETCHYBAR_DISPLAY_LIB_DIR="${BASH_SOURCE[0]%/*}"
[ "$SKETCHYBAR_DISPLAY_LIB_DIR" != "${BASH_SOURCE[0]}" ] || SKETCHYBAR_DISPLAY_LIB_DIR="."
if [ -r "$SKETCHYBAR_DISPLAY_LIB_DIR/runtime.sh" ]; then
  . "$SKETCHYBAR_DISPLAY_LIB_DIR/runtime.sh"
fi
for name in SKETCHYBAR_BIN HS_BIN; do
  if [ -z "${!name:-}" ] && type sketchybar_runtime_bin >/dev/null 2>&1; then
    case "$name" in
      SKETCHYBAR_BIN) SKETCHYBAR_BIN="$(sketchybar_runtime_bin "" sketchybar)" ;;
      HS_BIN) HS_BIN="$(sketchybar_runtime_bin "" hs)" ;;
    esac
  fi
done
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
HS_BIN="${HS_BIN:-/opt/homebrew/bin/hs}"
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"

sketchybar_display_warn() {
  if type sketchybar_warn_once >/dev/null 2>&1; then
    sketchybar_warn_once "$@"
  else
    shift || true
    printf 'sketchybar: %s\n' "$*" >&2
  fi
}

SKETCHYBAR_DISPLAY_ID="${SKETCHYBAR_DISPLAY_ID:-}"
sketchybar_display_id_for_monitor_var() {
  local monitor_name="$1" screens displays_json
  SKETCHYBAR_DISPLAY_ID=""
  [ -n "$monitor_name" ] || return 1
  if [ ! -x "$HS_BIN" ]; then
    sketchybar_display_warn hs-missing "Hammerspoon CLI (hs) not found; display identity unknown. No AeroSpace sequence-number fallback."
    return 1
  fi
  if [ ! -x "$PYTHON_BIN" ] || [ ! -x "$SKETCHYBAR_BIN" ]; then
    sketchybar_display_warn identity-missing "Display identity unknown: SketchyBar or Python unavailable."
    return 1
  fi
  if ! screens="$("$HS_BIN" -c 'for _, screen in ipairs(hs.screen.allScreens()) do print(screen:name() .. "\t" .. screen:id() .. "\t" .. screen:getUUID()) end' 2>/dev/null)"; then
    sketchybar_display_warn hs-query-failed "Hammerspoon screen query failed; leaving display targeting unchanged."
    return 1
  fi
  if ! displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null)"; then
    sketchybar_display_warn bar-query-failed "SketchyBar display query failed; leaving display targeting unchanged."
    return 1
  fi
  if ! SKETCHYBAR_DISPLAY_ID="$("$PYTHON_BIN" - "$monitor_name" "$screens" "$displays_json" <<'PY'
import json
import sys
try:
    name, screens, raw = sys.argv[1:]
    matches = [line.split("\t") for line in screens.splitlines()
               if line.split("\t")[0].casefold() == name.casefold()]
    if len(matches) != 1 or len(matches[0]) != 3:
        raise ValueError("missing or ambiguous monitor name")
    _, direct_id, uuid = matches[0]
    displays = json.loads(raw)
    if not isinstance(displays, list):
        raise ValueError("invalid display list")
    # A reported UUID is authoritative. DirectDisplayID is only a fallback
    # when the display payload does not carry a UUID; the two must not conflict.
    candidates = [d for d in displays if (
        str(d.get("UUID", "")).casefold() == uuid.casefold() if d.get("UUID") and uuid
        else str(d.get("DirectDisplayID", "")) == direct_id)]
    if len(candidates) != 1:
        raise ValueError("missing or ambiguous display identity")
    result = candidates[0].get("arrangement-id")
    if type(result) is not int or result <= 0:
        raise ValueError("invalid arrangement ID")
    print(result)
except (ValueError, TypeError, AttributeError):
    sys.exit(1)
PY
)"; then
    SKETCHYBAR_DISPLAY_ID=""
    sketchybar_display_warn identity-unknown "Missing or ambiguous display identity; refusing to guess another tool's display order."
    return 1
  fi
}

sketchybar_display_id_for_monitor() {
  sketchybar_display_id_for_monitor_var "$1" || return 1
  printf '%s\n' "$SKETCHYBAR_DISPLAY_ID"
}

sketchybar_visible_display_list_excluding() {
  local hidden_display_id="$1" displays_json
  [ -x "$SKETCHYBAR_BIN" ] && [ -x "$PYTHON_BIN" ] || return 1
  displays_json="$("$SKETCHYBAR_BIN" --query displays 2>/dev/null)" || return 1
  "$PYTHON_BIN" - "$hidden_display_id" "$displays_json" <<'PY'
import json
import sys
try:
    target = int(sys.argv[1])
    displays = json.loads(sys.argv[2])
    ids = [d["arrangement-id"] for d in displays]
    if (any(type(i) is not int or i <= 0 for i in ids) or
            len(set(ids)) != len(ids) or target not in ids):
        raise ValueError("invalid display IDs")
    visible = [str(i) for i in ids if i != target]
    # "all" would unhide the very display we were asked to hide.
    if not visible:
        raise ValueError("no remaining display")
    print(",".join(visible))
except (ValueError, TypeError, KeyError):
    sys.exit(1)
PY
}
