#!/usr/bin/env bash
# Read-only detection and recommendation helpers for bootstrap/advisor.sh.
#
# Keep this file compatible with the Bash 3.2 shipped by macOS. It may be
# sourced by tests; sourcing it performs no detection and writes nothing.

advisor_known_app_records() {
  # key|bundle id|display name|scene|workspace role|layout|app bundle names
  #
  # Bundle names are comma-separated and checked only in the standard macOS
  # application directories. Recommendations are emitted by exact bundle id,
  # never by executing metadata discovered on the machine.
  printf '%s\n' \
    'terminal|com.apple.Terminal|Terminal|coding|terminal|tiling|Terminal' \
    'warp|dev.warp.Warp-Stable|Warp|coding|terminal|tiling|Warp' \
    'kaku|fun.tw93.kaku|Kaku|coding|terminal|tiling|Kaku' \
    'goland|com.jetbrains.goland|GoLand|coding|development|tiling|GoLand' \
    'idea|com.jetbrains.intellij|IntelliJ IDEA|coding|development|tiling|IntelliJ IDEA,IntelliJ IDEA CE' \
    'vscode|com.microsoft.VSCode|Visual Studio Code|coding|development|tiling|Visual Studio Code' \
    'cursor|com.todesktop.230313mzl4w4u92|Cursor|coding|development|tiling|Cursor' \
    'sublime|com.sublimetext.4|Sublime Text|coding|development|tiling|Sublime Text' \
    'codex|com.openai.codex|Codex|ai|ai|tiling|Codex,OpenAI Codex' \
    'chatgpt|com.openai.chat|ChatGPT|ai|ai|tiling|ChatGPT' \
    'safari|com.apple.Safari|Safari|web|web|tiling|Safari' \
    'chrome|com.google.Chrome|Google Chrome|web|web|tiling|Google Chrome' \
    'edge|com.microsoft.edgemac|Microsoft Edge|web|web|tiling|Microsoft Edge' \
    'arc|company.thebrowser.Browser|Arc|web|web|tiling|Arc' \
    'dia|company.thebrowser.dia|Dia|web|research|tiling|Dia' \
    'firefox|org.mozilla.firefox|Firefox|web|web|tiling|Firefox' \
    'wechat|com.tencent.xinWeChat|WeChat|communication|communication|floating|WeChat,微信' \
    'slack|com.tinyspeck.slackmacgap|Slack|communication|communication|tiling|Slack' \
    'teams|com.microsoft.teams2|Microsoft Teams|communication|communication|tiling|Microsoft Teams' \
    'lark|com.electron.lark|Lark|communication|communication|floating|Lark,飞书' \
    'discord|com.hnc.Discord|Discord|communication|communication|floating|Discord' \
    'zoom|us.zoom.xos|zoom.us|communication|communication|floating|zoom.us' \
    'obsidian|md.obsidian|Obsidian|writing|notes|tiling|Obsidian' \
    'typora|abnerworks.Typora|Typora|writing|notes|tiling|Typora' \
    'miaoyan|com.tw93.miaoyan|MiaoYan|writing|notes|tiling|MiaoYan,妙言' \
    'obs|com.obsproject.obs-studio|OBS Studio|recording|stage|tiling|OBS,OBS Studio' \
    'camtasia|com.techsmith.camtasia|Camtasia|recording|stage|floating|Camtasia' \
    'snagit|com.TechSmith.Snagit|Snagit|recording|stage|floating|Snagit' \
    'spotify|com.spotify.client|Spotify|media|media|floating|Spotify' \
    'bilibili|com.bilibili.bilibiliPC|Bilibili|media|media|floating|Bilibili,哔哩哔哩'
}

advisor_word_list_contains() {
  local list="${1:-}" needle="${2:-}" item
  for item in $list; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

advisor_append_word_once() {
  local list="${1:-}" value="${2:-}"
  if advisor_word_list_contains "$list" "$value"; then
    printf '%s\n' "$list"
  else
    printf '%s\n' "${list:+$list }$value"
  fi
}

advisor_csv_to_words() {
  printf '%s\n' "${1:-}" | tr ',' ' ' | /usr/bin/awk '{$1=$1; print}'
}

advisor_validate_scenes() {
  local scenes="${1:-}" scene
  [ -n "$scenes" ] || return 1
  for scene in $scenes; do
    case "$scene" in
      coding|ai|web|communication|writing|recording|media) ;;
      *) printf 'Unknown scene: %s\n' "$scene" >&2; return 1 ;;
    esac
  done
}

advisor_value_is_profile_safe() {
  case "${1:-}" in
    *'"'*|*'$'*|*'`'*|*$'\n'*|*$'\r'*) return 1 ;;
  esac
  return 0
}

advisor_display_is_builtin_name() {
  case "${1:-}" in
    *Built-in*|*built-in*|*Internal*|*Color\ LCD*|*内建*|*内置*) return 0 ;;
  esac
  return 1
}

# macOS's own answer to "which screen owns the menu bar". Unlike the focused
# monitor it does not move with the pointer, so two runs of the advisor a
# second apart agree on the suggested main. Empty when the answer is
# unavailable; callers fall back to advisor_flag_default_main.
advisor_system_main_display_name() {
  local program
  command -v system_profiler >/dev/null 2>&1 || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  program="$(cat <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

for gpu in data.get("SPDisplaysDataType", []):
    for display in gpu.get("spdisplays_ndrvs", []):
        flag = str(display.get("spdisplays_main") or "").lower()
        if flag not in {"spdisplays_yes", "yes", "true", "1"}:
            continue
        name = str(display.get("_name") or "").strip()
        if name and not any(ch in name for ch in ['"', '$', '`', '\n', '\r']):
            print(name)
        raise SystemExit(0)
PY
)"
  system_profiler SPDisplaysDataType -json 2>/dev/null \
    | python3 -c "$program" 2>/dev/null || true
}

# Flags one row as the suggested main when macOS would not say. The first
# external screen beats the built-in panel: on a docked laptop the built-in one
# is almost never the screen the user calls main, and either way the answer has
# to be the same on every run.
advisor_flag_default_main() {
  local file="$1" want=''
  want="$(/usr/bin/awk -F '|' 'NF >= 3 { count++; if ($3 == 0) { print count; exit } }' "$file" || true)"
  [ -n "$want" ] || want=1
  /usr/bin/awk -F '|' -v want="$want" 'BEGIN { OFS = "|" }
    { count++; if (count == want) { $2 = 1 } print }' "$file" >"${file}.main"
  mv "${file}.main" "$file"
}

advisor_detect_displays() {
  local output_file="$1" fixture="${AI_FIRST_ADVISOR_DISPLAYS_FILE:-}"
  local lines main_hint='' name index=0 builtin=0 main=0

  : >"$output_file"
  ADVISOR_DISPLAY_SOURCE='fallback'
  ADVISOR_DISPLAY_NAMES_RELIABLE=0
  # A display whose name cannot be stored safely is dropped, which silently
  # changes the detected count and therefore the recommendation. Count them so
  # the preview can say so out loud.
  ADVISOR_DISPLAYS_SKIPPED=0
  export ADVISOR_DISPLAYS_SKIPPED

  if [ -n "$fixture" ] && [ -r "$fixture" ]; then
    while IFS='|' read -r name main builtin rest; do
      case "$name" in ''|'#'*) continue ;; esac
      [ -z "${rest:-}" ] || continue
      if ! advisor_value_is_profile_safe "$name"; then
        ADVISOR_DISPLAYS_SKIPPED=$((ADVISOR_DISPLAYS_SKIPPED + 1))
        continue
      fi
      case "$main" in 0|1) ;; *) main=0 ;; esac
      case "$builtin" in 0|1) ;; *) builtin=0 ;; esac
      printf '%s|%s|%s\n' "$name" "$main" "$builtin" >>"$output_file"
    done <"$fixture"
    if [ -s "$output_file" ]; then
      ADVISOR_DISPLAY_SOURCE='fixture'
      ADVISOR_DISPLAY_NAMES_RELIABLE=1
      export ADVISOR_DISPLAY_SOURCE ADVISOR_DISPLAY_NAMES_RELIABLE
      return 0
    fi
  fi

  if command -v aerospace >/dev/null 2>&1; then
    lines="$(aerospace list-monitors --format '%{monitor-name}' 2>/dev/null || true)"
    if [ -n "$lines" ]; then
      # `list-monitors --focused` answers "where is the pointer right now", not
      # "which screen is main": the suggested main changed between two runs of
      # the advisor because the mouse had moved to the side monitor in between.
      main_hint="$(advisor_system_main_display_name)"
      while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! advisor_value_is_profile_safe "$name"; then
          ADVISOR_DISPLAYS_SKIPPED=$((ADVISOR_DISPLAYS_SKIPPED + 1))
          continue
        fi
        index=$((index + 1))
        main=0
        builtin=0
        if [ -n "$main_hint" ] && [ "$name" = "$main_hint" ]; then main=1; fi
        advisor_display_is_builtin_name "$name" && builtin=1
        printf '%s|%s|%s\n' "$name" "$main" "$builtin" >>"$output_file"
      done <<EOF
$lines
EOF
      if [ -s "$output_file" ]; then
        if ! /usr/bin/grep -Eq '\|1\|[01]$' "$output_file"; then
          advisor_flag_default_main "$output_file"
        fi
        ADVISOR_DISPLAY_SOURCE='AeroSpace'
        ADVISOR_DISPLAY_NAMES_RELIABLE=1
        export ADVISOR_DISPLAY_SOURCE ADVISOR_DISPLAY_NAMES_RELIABLE
        return 0
      fi
    fi
  fi

  if command -v hs >/dev/null 2>&1; then
    lines="$(hs -c 'for index, screen in ipairs(hs.screen.allScreens()) do print(index .. "|" .. screen:name() .. "|" .. (screen == hs.screen.primaryScreen() and "1" or "0")) end' 2>/dev/null || true)"
    if [ -n "$lines" ]; then
      while IFS='|' read -r _index name main rest; do
        [ -z "${rest:-}" ] || continue
        [ -n "$name" ] || continue
        if ! advisor_value_is_profile_safe "$name"; then
          ADVISOR_DISPLAYS_SKIPPED=$((ADVISOR_DISPLAYS_SKIPPED + 1))
          continue
        fi
        builtin=0
        advisor_display_is_builtin_name "$name" && builtin=1
        case "$main" in 0|1) ;; *) main=0 ;; esac
        printf '%s|%s|%s\n' "$name" "$main" "$builtin" >>"$output_file"
      done <<EOF
$lines
EOF
      if [ -s "$output_file" ]; then
        ADVISOR_DISPLAY_SOURCE='Hammerspoon'
        ADVISOR_DISPLAY_NAMES_RELIABLE=1
        export ADVISOR_DISPLAY_SOURCE ADVISOR_DISPLAY_NAMES_RELIABLE
        return 0
      fi
    fi
  fi

  if command -v system_profiler >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    local json_file="${output_file}.json"
    local skipped_file="${output_file}.skipped"
    rm -f "$skipped_file"
    if system_profiler SPDisplaysDataType -json >"$json_file" 2>/dev/null; then
      python3 - "$json_file" "$output_file" "$skipped_file" <<'PY' || true
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
skipped_target = pathlib.Path(sys.argv[3])
try:
    data = json.loads(source.read_text())
except Exception:
    raise SystemExit(0)

seen = set()
rows = []
skipped = 0
for gpu in data.get("SPDisplaysDataType", []):
    for display in gpu.get("spdisplays_ndrvs", []):
        name = str(display.get("_name") or "").strip()
        if not name or name in seen:
            continue
        if any(ch in name for ch in ['"', '$', '`', '\n', '\r']):
            skipped += 1
            continue
        seen.add(name)
        display_type = str(display.get("spdisplays_display_type") or "").lower()
        builtin = int("built" in display_type or "built-in" in name.lower() or "color lcd" in name.lower())
        main_value = str(display.get("spdisplays_main") or "").lower()
        main = int(main_value in {"spdisplays_yes", "yes", "true", "1"})
        rows.append([name, main, builtin])
if rows and not any(row[1] for row in rows):
    # Same tie-break as advisor_flag_default_main: the first external screen,
    # and only then the first row, so the suggestion never depends on a pointer.
    external = [row for row in rows if not row[2]]
    (external[0] if external else rows[0])[1] = 1
target.write_text("".join(f"{name}|{main}|{builtin}\n" for name, main, builtin in rows))
skipped_target.write_text(f"{skipped}\n")
PY
    fi
    rm -f "$json_file"
    if [ -r "$skipped_file" ]; then
      ADVISOR_DISPLAYS_SKIPPED="$(/usr/bin/awk 'NR == 1 { print $1 + 0; exit }' "$skipped_file" || true)"
      case "$ADVISOR_DISPLAYS_SKIPPED" in ''|*[!0-9]*) ADVISOR_DISPLAYS_SKIPPED=0 ;; esac
      rm -f "$skipped_file"
    fi
    if [ -s "$output_file" ]; then
      ADVISOR_DISPLAY_SOURCE='system_profiler'
      ADVISOR_DISPLAY_NAMES_RELIABLE=1
      export ADVISOR_DISPLAY_SOURCE ADVISOR_DISPLAY_NAMES_RELIABLE
      return 0
    fi
  fi

  # Newer macOS versions can omit display dictionaries from system_profiler,
  # while CoreGraphics still knows the active count. Count-only data is enough
  # for the default flexible layout; fixed names are deliberately refused by
  # the CLI until AeroSpace/Hammerspoon can provide real names.
  if command -v python3 >/dev/null 2>&1; then
    local active_count
    active_count="$(python3 - <<'PY' 2>/dev/null || true
import ctypes

try:
    core_graphics = ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
    count = ctypes.c_uint32()
    result = core_graphics.CGGetActiveDisplayList(0, None, ctypes.byref(count))
    print(count.value if result == 0 else 0)
except Exception:
    print(0)
PY
)"
    case "$active_count" in ''|*[!0-9]*) active_count=0 ;; esac
    if [ "$active_count" -gt 0 ]; then
      index=1
      while [ "$index" -le "$active_count" ]; do
        main=0
        [ "$index" -eq 1 ] && main=1
        printf 'Display %s|%s|0\n' "$index" "$main" >>"$output_file"
        index=$((index + 1))
      done
      ADVISOR_DISPLAY_SOURCE='CoreGraphics count only'
      ADVISOR_DISPLAY_NAMES_RELIABLE=0
      export ADVISOR_DISPLAY_SOURCE ADVISOR_DISPLAY_NAMES_RELIABLE
      return 0
    fi
  fi

  printf 'Automatic display|1|1\n' >"$output_file"
  ADVISOR_DISPLAY_SOURCE='fallback'
  ADVISOR_DISPLAY_NAMES_RELIABLE=0
  export ADVISOR_DISPLAY_SOURCE ADVISOR_DISPLAY_NAMES_RELIABLE
}

advisor_display_count() {
  /usr/bin/awk -F '|' 'NF >= 3 { count++ } END { print count + 0 }' "$1"
}

# `index` is an awk built-in function name. Passing it as -v index=... parses,
# but referencing it in the program body is a syntax error on the awk macOS
# ships, so this function used to fail on every call and return nothing: the
# interactive fixed-display chooser rejected every number the user typed, and a
# three-display desk with no built-in screen silently got an empty stage name.
advisor_display_name_at() {
  /usr/bin/awk -F '|' -v want="$2" 'NF >= 3 { count++; if (count == want) { print $1; exit } }' "$1"
}

advisor_default_main_display() {
  local value
  value="$(/usr/bin/awk -F '|' '$2 == 1 { print $1; exit }' "$1")"
  [ -n "$value" ] || value="$(advisor_display_name_at "$1" 1)"
  printf '%s\n' "$value"
}

advisor_default_stage_display() {
  local value
  value="$(/usr/bin/awk -F '|' '$3 == 1 { print $1; exit }' "$1")"
  [ -n "$value" ] || value="$(advisor_display_name_at "$1" "$(advisor_display_count "$1")")"
  printf '%s\n' "$value"
}

advisor_default_side_display() {
  local file="$1" main_name="${2:-}" stage_name="${3:-}" value
  value="$(/usr/bin/awk -F '|' -v main="$main_name" -v stage="$stage_name" \
    '$1 != main && $1 != stage { print $1; exit }' "$file")"
  if [ -z "$value" ]; then
    value="$(/usr/bin/awk -F '|' -v main="$main_name" '$1 != main { print $1; exit }' "$file")"
  fi
  printf '%s\n' "$value"
}

# Names reported by more than one display, in detection order.
#
# AeroSpace addresses monitors by name, so two screens answering to the same
# one cannot be told apart. Both filters in advisor_default_side_display drop
# every row whose name equals main, which for a duplicated name is *all* of
# them: the side name came back empty, the distinctness checks in
# bootstrap/advisor.sh were short-circuited by that empty value, and a fixed
# desk was written with side workspaces and no side display - a half-pinned
# desk that reads exactly like a working one.
advisor_duplicate_display_names() {
  /usr/bin/awk -F '|' '
    NF >= 3 {
      seen[$1]++
      if (seen[$1] == 1) { total++; order[total] = $1 }
    }
    END {
      for (position = 1; position <= total; position++) {
        if (seen[order[position]] > 1) { print order[position] }
      }
    }' "$1"
}

# Displays that no role in the plan will land on.
#
# The layout is deliberately three-role - main, side, stage - so a fourth
# screen is not a bug. Leaving the user to notice on their own that it carries
# nothing is. Each role name is consumed once, so a duplicated name does not
# mask a genuinely unused screen.
advisor_unused_display_names() {
  local file="$1" main_name="${2:-}" side_name="${3:-}" stage_name="${4:-}"
  /usr/bin/awk -F '|' \
    -v main_name="$main_name" -v side_name="$side_name" -v stage_name="$stage_name" '
    NF >= 3 {
      if (main_name != "" && $1 == main_name && !used_main) { used_main = 1; next }
      if (side_name != "" && $1 == side_name && !used_side) { used_side = 1; next }
      if (stage_name != "" && $1 == stage_name && !used_stage) { used_stage = 1; next }
      print $1
    }' "$file"
}

advisor_app_bundle_exists() {
  local app_names="$1" app_name root
  local old_ifs="$IFS"
  IFS=','
  for app_name in $app_names; do
    IFS="$old_ifs"
    for root in /Applications "$HOME/Applications" /System/Applications /System/Applications/Utilities; do
      [ -d "$root/$app_name.app" ] && return 0
    done
    IFS=','
  done
  IFS="$old_ifs"
  return 1
}

advisor_detect_apps() {
  local output_file="$1" fixture="${AI_FIRST_ADVISOR_APPLICATIONS_FILE:-}"
  local fixture_content='' key bundle display scene role layout app_names

  : >"$output_file"
  if [ -n "$fixture" ] && [ -r "$fixture" ]; then
    fixture_content="$(/usr/bin/awk -F '|' 'NF { print $1 }' "$fixture")"
  fi

  while IFS='|' read -r key bundle display scene role layout app_names rest; do
    [ -z "${rest:-}" ] || continue
    if [ -n "$fixture_content" ]; then
      if printf '%s\n' "$fixture_content" | /usr/bin/grep -Fxq "$bundle" || \
         printf '%s\n' "$fixture_content" | /usr/bin/grep -Fxq "$key"; then
        printf '%s|%s|%s|%s|%s|%s\n' "$key" "$bundle" "$display" "$scene" "$role" "$layout" >>"$output_file"
      fi
    elif advisor_app_bundle_exists "$app_names"; then
      printf '%s|%s|%s|%s|%s|%s\n' "$key" "$bundle" "$display" "$scene" "$role" "$layout" >>"$output_file"
    fi
  done <<EOF
$(advisor_known_app_records)
EOF
}

advisor_detected_scenes() {
  local apps_file="$1" scenes='' scene
  while IFS='|' read -r _key _bundle _display scene _role _layout _rest; do
    [ -n "$scene" ] || continue
    # Recording and media are visible choices, but merely having OBS or Spotify
    # installed does not mean they shape the user's daily workspace model.
    # They become defaults only when the user selects them explicitly.
    case "$scene" in recording|media) continue ;; esac
    scenes="$(advisor_append_word_once "$scenes" "$scene")"
  done <"$apps_file"
  scenes="$(advisor_append_word_once "$scenes" web)"
  [ -n "$scenes" ] || scenes='coding web'
  printf '%s\n' "$scenes"
}

advisor_scene_count() {
  local count=0 item
  for item in ${1:-}; do count=$((count + 1)); done
  printf '%s\n' "$count"
}

# How many workspaces, from task load alone.
#
# `display_count` used to be an independent OR condition here, so plugging in a
# second screen jumped a single-scene desk straight from 4 workspaces to 8 -
# the same person, the same work, twice the workspaces. That contradicted what
# docs/choice-architecture.md and the README both promise: the count comes from
# task load, and the display count only decides how those workspaces are
# grouped across main/side/stage. Grouping still reads the display count, in
# advisor_build_workspace_plan; the count no longer does.
#
# The second argument is accepted and ignored so an older caller cannot
# silently pass a display count that quietly stops mattering.
advisor_recommend_workspace_mode() {
  local scenes="$1" scene_count
  scene_count="$(advisor_scene_count "$scenes")"
  if [ "$scene_count" -ge 7 ]; then
    printf 'advanced\n'
  elif advisor_word_list_contains "$scenes" recording && [ "$scene_count" -ge 6 ]; then
    # A recording desk needs a stage that survives everything else being busy.
    printf 'advanced\n'
  elif [ "$scene_count" -ge 5 ]; then
    printf 'multitask\n'
  elif [ "$scene_count" -ge 3 ]; then
    printf 'balanced\n'
  else
    printf 'focus\n'
  fi
}

advisor_workspace_mode_step() {
  local mode="$1" direction="$2"
  case "$direction:$mode" in
    fewer:advanced) printf 'multitask\n' ;;
    fewer:multitask) printf 'balanced\n' ;;
    fewer:balanced) printf 'focus\n' ;;
    more:focus) printf 'balanced\n' ;;
    more:balanced) printf 'multitask\n' ;;
    more:multitask) printf 'advanced\n' ;;
    keep:*|fewer:focus|more:advanced) printf '%s\n' "$mode" ;;
    *) return 1 ;;
  esac
}

# Result globals populated by advisor_build_workspace_plan.
ADVISOR_WORKSPACES=''
ADVISOR_MAIN_WORKSPACES=''
ADVISOR_SIDE_WORKSPACES=''
ADVISOR_STAGE_WORKSPACES=''
ADVISOR_ROLE_MAP=''

advisor_build_workspace_plan() {
  local mode="$1" display_count="$2"
  case "$mode" in
    focus)
      ADVISOR_WORKSPACES='1 2 3 4'
      ADVISOR_ROLE_MAP='focus:1 development:1 terminal:2 ai:3 support:3 web:3 research:3 communication:4 notes:4 utility:4 system:4 media:4 broadcast:4 stage:4'
      case "$display_count" in
        1) ADVISOR_MAIN_WORKSPACES="$ADVISOR_WORKSPACES"; ADVISOR_SIDE_WORKSPACES=''; ADVISOR_STAGE_WORKSPACES='' ;;
        2) ADVISOR_MAIN_WORKSPACES='1 2 3'; ADVISOR_SIDE_WORKSPACES='4'; ADVISOR_STAGE_WORKSPACES='' ;;
        *) ADVISOR_MAIN_WORKSPACES='1 2'; ADVISOR_SIDE_WORKSPACES='3'; ADVISOR_STAGE_WORKSPACES='4' ;;
      esac
      ;;
    balanced)
      ADVISOR_WORKSPACES='1 2 3 4 5 6'
      ADVISOR_ROLE_MAP='focus:1 development:1 terminal:2 ai:3 support:3 web:4 research:4 communication:5 notes:5 utility:6 system:6 media:6 broadcast:6 stage:6'
      case "$display_count" in
        1) ADVISOR_MAIN_WORKSPACES="$ADVISOR_WORKSPACES"; ADVISOR_SIDE_WORKSPACES=''; ADVISOR_STAGE_WORKSPACES='' ;;
        2) ADVISOR_MAIN_WORKSPACES='1 2 3 4'; ADVISOR_SIDE_WORKSPACES='5 6'; ADVISOR_STAGE_WORKSPACES='' ;;
        *) ADVISOR_MAIN_WORKSPACES='1 2 3'; ADVISOR_SIDE_WORKSPACES='4 5'; ADVISOR_STAGE_WORKSPACES='6' ;;
      esac
      ;;
    multitask)
      ADVISOR_WORKSPACES='1 2 3 4 5 6 7 8'
      ADVISOR_ROLE_MAP='focus:1 development:1 terminal:2 ai:3 support:4 web:4 research:5 communication:6 notes:7 utility:7 system:7 media:8 broadcast:8 stage:8'
      case "$display_count" in
        1) ADVISOR_MAIN_WORKSPACES="$ADVISOR_WORKSPACES"; ADVISOR_SIDE_WORKSPACES=''; ADVISOR_STAGE_WORKSPACES='' ;;
        2) ADVISOR_MAIN_WORKSPACES='1 2 3 4 5'; ADVISOR_SIDE_WORKSPACES='6 7 8'; ADVISOR_STAGE_WORKSPACES='' ;;
        *) ADVISOR_MAIN_WORKSPACES='1 2 3 4'; ADVISOR_SIDE_WORKSPACES='5 6 7'; ADVISOR_STAGE_WORKSPACES='8' ;;
      esac
      ;;
    advanced)
      ADVISOR_WORKSPACES='1 2 3 4 5 6 7 8 9 10'
      ADVISOR_ROLE_MAP='focus:1 development:1 terminal:2 ai:3 support:4 web:4 research:5 communication:6 notes:7 utility:8 system:8 media:9 broadcast:10 stage:10'
      case "$display_count" in
        1) ADVISOR_MAIN_WORKSPACES="$ADVISOR_WORKSPACES"; ADVISOR_SIDE_WORKSPACES=''; ADVISOR_STAGE_WORKSPACES='' ;;
        2) ADVISOR_MAIN_WORKSPACES='1 2 3 4 5 6'; ADVISOR_SIDE_WORKSPACES='7 8 9 10'; ADVISOR_STAGE_WORKSPACES='' ;;
        *) ADVISOR_MAIN_WORKSPACES='1 2 3 4 5'; ADVISOR_SIDE_WORKSPACES='6 7 8 9'; ADVISOR_STAGE_WORKSPACES='10' ;;
      esac
      ;;
    *) printf 'Workspace mode must be focus, balanced, multitask, advanced, or auto.\n' >&2; return 1 ;;
  esac
  export ADVISOR_WORKSPACES ADVISOR_MAIN_WORKSPACES ADVISOR_SIDE_WORKSPACES
  export ADVISOR_STAGE_WORKSPACES ADVISOR_ROLE_MAP
}

advisor_recommended_modules() {
  local scenes="$1" modules='workspace bar'
  if advisor_word_list_contains "$scenes" ai; then
    modules="$(advisor_append_word_once "$modules" capslock)"
    modules="$(advisor_append_word_once "$modules" automation)"
    modules="$(advisor_append_word_once "$modules" ai)"
  fi
  if advisor_word_list_contains "$scenes" recording; then
    modules="$(advisor_append_word_once "$modules" automation)"
    modules="$(advisor_append_word_once "$modules" recording)"
  fi
  printf '%s\n' "$modules"
}

advisor_generate_profile() {
  local output_file="$1" scenes="$2" workspace_mode="$3" desk_mode="$4"
  local placement="$5" routing_pack="$6" terminal_app="$7"
  local main_monitor="$8" side_monitor="$9" stage_monitor="${10}"
  local ai_enabled=0 recording_enabled=0 profile_value

  advisor_word_list_contains "$scenes" ai && ai_enabled=1
  advisor_word_list_contains "$scenes" recording && recording_enabled=1

  for profile_value in "$scenes" "$workspace_mode" "$desk_mode" "$placement" "$routing_pack" \
    "$terminal_app" "$main_monitor" "$side_monitor" "$stage_monitor" \
    "$ADVISOR_MAIN_WORKSPACES" "$ADVISOR_SIDE_WORKSPACES" "$ADVISOR_STAGE_WORKSPACES" "$ADVISOR_ROLE_MAP"; do
    if ! advisor_value_is_profile_safe "$profile_value"; then
      printf 'Unsafe value cannot be written to the data-only profile: %s\n' "$profile_value" >&2
      return 1
    fi
  done

  cat >"$output_file" <<EOF
# Generated by ./bootstrap/setup.sh recommend. Re-running the advisor previews
# changes first and backs this file up before replacing it.
AI_FIRST_PRESET="advisor"
AI_FIRST_ADVISOR_SCENES="$scenes"
AI_FIRST_ADVISOR_WORKSPACE_MODE="$workspace_mode"
AI_FIRST_ADVISOR_DESK_MODE="$desk_mode"
AI_FIRST_ADVISOR_PLACEMENT="$placement"
AI_FIRST_APP_ROUTING="1"
AI_FIRST_ROUTING_PACK="$routing_pack"
AI_FIRST_FEATURE_AI_HOTKEYS="$ai_enabled"
AI_FIRST_FEATURE_NOTIFICATIONS="0"
AI_FIRST_FEATURE_RECORDING="$recording_enabled"
AI_FIRST_BAR_LEFT_ITEMS="apple spaces aerospace_layout front_app"
AI_FIRST_BAR_CENTER_ITEMS="media"
AI_FIRST_BAR_RIGHT_ITEMS="clock calendar battery volume"
AI_FIRST_NOTIFICATION_APPS=""
AI_FIRST_TERMINAL_APP="$terminal_app"
AEROSPACE_MAIN_MONITOR_NAME="$main_monitor"
AEROSPACE_SIDE_MONITOR_NAME="$side_monitor"
AEROSPACE_STAGE_MONITOR_NAME="$stage_monitor"
AEROSPACE_MAIN_WORKSPACES="$ADVISOR_MAIN_WORKSPACES"
AEROSPACE_SIDE_WORKSPACES="$ADVISOR_SIDE_WORKSPACES"
AEROSPACE_STAGE_WORKSPACES="$ADVISOR_STAGE_WORKSPACES"
AEROSPACE_WORKSPACE_ROLE_MAP="$ADVISOR_ROLE_MAP"
EOF
}

# Roles that more than one detected app would compete for.
advisor_contended_roles() {
  local apps_file="$1" scenes="$2" seen='' contended=''
  local key bundle display scene role layout rest
  while IFS='|' read -r key bundle display scene role layout rest; do
    [ -z "${rest:-}" ] || continue
    advisor_word_list_contains "$scenes" "$scene" || continue
    if advisor_word_list_contains "$seen" "$role"; then
      contended="$(advisor_append_word_once "$contended" "$role")"
    else
      seen="$(advisor_append_word_once "$seen" "$role")"
    fi
  done <"$apps_file"
  printf '%s\n' "$contended"
}

# Detected app keys for one role, in catalog order.
advisor_role_app_keys() {
  local apps_file="$1" scenes="$2" want_role="$3" keys=''
  local key bundle display scene role layout rest
  while IFS='|' read -r key bundle display scene role layout rest; do
    [ -z "${rest:-}" ] || continue
    advisor_word_list_contains "$scenes" "$scene" || continue
    [ "$role" = "$want_role" ] || continue
    keys="$(advisor_append_word_once "$keys" "$key")"
  done <"$apps_file"
  printf '%s\n' "$keys"
}

# Looks a role up in a newline-separated "role|value" list. A plain word list
# will not do: display names contain spaces.
advisor_lookup_role_value() {
  local pairs="${1:-}" want_role="$2" pair_role pair_value
  [ -n "$pairs" ] || return 1
  while IFS='|' read -r pair_role pair_value; do
    [ "$pair_role" = "$want_role" ] || continue
    printf '%s\n' "$pair_value"
    return 0
  done <<EOF
$pairs
EOF
  return 1
}

# Which app owns a role, when the caller asked interactively. Space-separated
# "role:key" pairs, so it stays a plain word list.
advisor_primary_app_for_role() {
  local pairs="${1:-}" want_role="$2" pair
  for pair in $pairs; do
    case "$pair" in
      "$want_role":?*) printf '%s\n' "${pair#*:}"; return 0 ;;
    esac
  done
  return 1
}

# Apps whose role was already claimed, as "display|role|owner display" lines.
ADVISOR_DOWNGRADED_ROUTES=''

# `prefer` and `fixed` both mean "send new windows of this app to this
# workspace". Emitting one for every app of a role means three terminals, four
# IDEs and five browsers all pointing at three workspaces - every window of all
# of them piling onto the same screen, which is nobody's idea of a preference.
# One app per role keeps the promise; the rest stay where they are opened, and
# the preview says which ones and why.
advisor_generate_routes() {
  local output_file="$1" apps_file="$2" scenes="$3" placement="$4"
  local primary_apps="${5:-}"
  local key bundle display scene role layout rest target policy
  local claimed='' owner_keys='' owner_names='' primary_key='' owner_key='' owner_display=''

  case "$placement" in follow|prefer|fixed) ;; *) return 1 ;; esac
  ADVISOR_DOWNGRADED_ROUTES=''

  # First pass: decide who owns each role, so the second pass can name the
  # owner even when the user picked an app that sorts after the others.
  if [ "$placement" != 'follow' ]; then
    while IFS='|' read -r key bundle display scene role layout rest; do
      [ -z "${rest:-}" ] || continue
      advisor_word_list_contains "$scenes" "$scene" || continue
      primary_key="$(advisor_primary_app_for_role "$primary_apps" "$role" || true)"
      if [ -n "$primary_key" ]; then
        [ "$key" = "$primary_key" ] || continue
      elif advisor_word_list_contains "$claimed" "$role"; then
        continue
      fi
      claimed="$(advisor_append_word_once "$claimed" "$role")"
      owner_keys="${owner_keys:+$owner_keys }$role:$key"
      owner_names="${owner_names}${role}|${display}
"
    done <"$apps_file"
  fi

  {
    printf '# Generated locally by ./bootstrap/setup.sh recommend.\n'
    printf '# Detected applications only; user app-routes.conf has higher priority.\n'
    printf '# At most one prefer/fixed route per workspace role: further apps of the\n'
    printf '# same role follow the current workspace instead of crowding onto one.\n'
    printf '# match|value|target|policy|layout\n'
    while IFS='|' read -r key bundle display scene role layout rest; do
      [ -z "${rest:-}" ] || continue
      advisor_word_list_contains "$scenes" "$scene" || continue
      target='current'
      policy='follow'
      if [ "$placement" != 'follow' ]; then
        owner_key="$(advisor_primary_app_for_role "$owner_keys" "$role" || true)"
        if [ "$key" = "$owner_key" ]; then
          target="$role"
          policy="$placement"
        else
          owner_display="$(advisor_lookup_role_value "$owner_names" "$role" || true)"
          ADVISOR_DOWNGRADED_ROUTES="${ADVISOR_DOWNGRADED_ROUTES}${display}|${role}|${owner_display}
"
        fi
      fi
      printf 'id|%s|%s|%s|%s\n' "$bundle" "$target" "$policy" "$layout"
    done <"$apps_file"
  } >"$output_file"
  export ADVISOR_DOWNGRADED_ROUTES
}

# Delegates to the shared reader in bootstrap/catalog.sh, which bootstrap/
# advisor.sh sources first. The fallback keeps this file usable on its own, as
# its header promises: a test may source it directly, with no catalog present.
advisor_profile_get() {
  if type ai_first_profile_conf_get >/dev/null 2>&1; then
    ai_first_profile_conf_get "$1" "$2"
    return
  fi

  local file="$1" key="$2"
  [ -r "$file" ] || return 1
  /usr/bin/awk -v key="$key" '
    index($0, key "=\"") == 1 {
      value = substr($0, length(key) + 3)
      if (substr(value, length(value), 1) == "\"") {
        print substr(value, 1, length(value) - 1)
        found = 1
        exit
      }
    }
    END { if (!found) exit 1 }
  ' "$file"
}
