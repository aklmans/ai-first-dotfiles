#!/usr/bin/env bash
set -euo pipefail

# Pins four things that were broken or missing in the routing and diagnostics
# layer.
#
# 1. `plan.sh --check` was dead code. Both branches at the end of the file ran
#    `exit 1`, so the flag the header describes as "makes invalid data a
#    non-zero result for doctor/CI" changed nothing, and the plain form - the
#    one a person runs to read a report - failed on any imperfect config.
#
# 2. plan.sh only ever validated the AeroSpace side. Four programs derive their
#    behaviour from the same two config files and nothing compared them, so a
#    profile that moved the stage workspace left SketchyBar painting chips for
#    workspaces AeroSpace does not have and Recording Mode parking windows on a
#    workspace that no longer exists, both silently.
#
# 3. `AI_FIRST_ROUTING_PACK="none"` is documented as shipping no app placement,
#    but should_float_window carried ~80 lines of specific application names in
#    a `case` block that ran whatever pack was selected. A minimal install
#    floated Clash for Windows, WeChat, Bilibili and Spotify because of who
#    wrote the repo. Those lists now live in routing-packs/, so `none` means
#    none and `author` still reproduces the author's desk exactly.
#
# 4. printf pads by bytes. A `%-34s`/`%-38s` holding `微信` counted six and
#    threw every column after it out of line, in plan.sh and in
#    `app-route.sh list` alike.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/assert.sh
. "$repo_root/tests/smoke/lib/assert.sh"

system_bash="/bin/bash"
if [ ! -x "$system_bash" ]; then
  printf 'Missing %s; this must be exercised on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/cross-tool-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

# A HOME with only the AeroSpace side deployed, which is what most of the route
# assertions need and what makes the cross-tool checks report "skip".
new_bare_home() {
  local home_dir
  home_dir="$(mktemp -d "$sandbox_root/home.XXXXXX")"
  mkdir -p "$home_dir/.config"
  cp -R "$repo_root/home/.config/aerospace" "$home_dir/.config/aerospace"
  cp -R "$repo_root/home/.config/ai-first" "$home_dir/.config/ai-first"
  printf '%s\n' "$home_dir"
}

# The full four-tool deployment, so the consistency checks have something to
# compare instead of skipping.
new_full_home() {
  local home_dir
  home_dir="$(new_bare_home)"
  mkdir -p "$home_dir/.hammerspoon"
  cp -R "$repo_root/home/.config/sketchybar" "$home_dir/.config/sketchybar"
  cp -R "$repo_root/home/.config/karabiner" "$home_dir/.config/karabiner"
  cp "$repo_root/home/.hammerspoon/screencast.lua" "$home_dir/.hammerspoon/screencast.lua"
  cp "$repo_root/home/.aerospace.toml" "$home_dir/.aerospace.toml"
  printf '%s\n' "$home_dir"
}

# Swallows the exit status on purpose: several of the calls below are expected
# to fail, and under `set -e` a failing command substitution in an assignment
# aborts the suite and hides every assertion after it.
in_home() {
  local home_dir="$1"
  shift
  env -u AI_ROUTER_HOME -u BORDERS_START_SERVICE -u DOTFILES_FORCE \
      -u XDG_CACHE_HOME -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME \
      -u AI_FIRST_ROUTING_PACK -u AI_FIRST_APP_ROUTES_FILE -u AI_FIRST_PRESET \
      -u AEROSPACE_CONFIG_DIR -u SKETCHYBAR_WORKSPACES \
      "HOME=$home_dir" "$system_bash" "$@" 2>&1 || true
}

plan_status() {
  local home_dir="$1"
  shift
  local status=0
  env -u AI_ROUTER_HOME -u XDG_CONFIG_HOME -u XDG_STATE_HOME \
      -u AEROSPACE_CONFIG_DIR -u SKETCHYBAR_WORKSPACES \
      "HOME=$home_dir" "$system_bash" "$home_dir/.config/aerospace/plan.sh" "$@" \
      >/dev/null 2>&1 || status=$?
  printf '%s' "$status"
}

# --- plan.sh exit codes ------------------------------------------------------
#
# A route naming a role that does not exist is invalid data, which is what the
# two forms have to disagree about.

bad_home="$(new_bare_home)"
printf 'id|com.example.Bad|nosuchrole|prefer|tiling\n' >"$bad_home/.config/aerospace/app-routes.conf"

assert_equal '0' "$(plan_status "$bad_home")" \
  'the plain form is a report and must exit 0 even when it found something'
assert_equal '1' "$(plan_status "$bad_home" --check)" \
  '--check must be the flag that turns the same report into a non-zero result'

bad_plan="$(in_home "$bad_home" "$bad_home/.config/aerospace/plan.sh")"
assert_contains "$bad_plan" 'User route is invalid' \
  'the plain form must still say what it found'
assert_output_matches "$bad_plan" '^Result: 1 invalid setting' \
  'the plain form must summarise what it found'

good_home="$(new_bare_home)"
assert_equal '0' "$(plan_status "$good_home" --check)" \
  '--check must pass on a config with nothing wrong with it'
assert_contains "$(in_home "$good_home" "$good_home/.config/aerospace/plan.sh" --check)" \
  'Result: valid' 'a clean config must be reported as valid'

# --- cross-tool consistency --------------------------------------------------

absent_plan="$(in_home "$good_home" "$good_home/.config/aerospace/plan.sh")"
assert_contains "$absent_plan" 'Cross-tool consistency:' \
  'the plan must have a cross-tool section'
assert_output_matches "$absent_plan" 'skip .*SketchyBar is not deployed' \
  'a tool that is not installed must be skipped with a reason, not silently passed'
assert_output_matches "$absent_plan" 'skip .*Hammerspoon Recording Mode is not deployed' \
  'Recording Mode must be skipped with a reason when Hammerspoon is not deployed'
assert_output_matches "$absent_plan" 'skip .*Karabiner-Elements is not configured' \
  'Karabiner must be skipped with a reason when it is not configured'
assert_output_matches "$absent_plan" 'skip .*no AeroSpace config at' \
  'the rendered TOML check must be skipped with a reason when there is no config'

full_home="$(new_full_home)"
full_plan="$(in_home "$full_home" "$full_home/.config/aerospace/plan.sh" --check)"
assert_output_matches "$full_plan" 'ok .*SketchyBar chips match' \
  'a consistent SketchyBar deployment must be reported as consistent'
assert_output_matches "$full_plan" 'ok .*Recording Mode parks on workspace 13' \
  'Recording Mode must resolve inside the configured stage group'
assert_output_matches "$full_plan" 'ok .*Karabiner: all [0-9]+ shipped rule' \
  'the shipped Karabiner rules must be reported as enabled'
assert_output_matches "$full_plan" 'ok .*matches workspaces.conf and displays.conf' \
  'the shipped .aerospace.toml must match the shipped workspace config'
assert_equal '0' "$(plan_status "$full_home" --check)" \
  'a consistent four-tool deployment must pass --check'

# karabiner.json is a running driver's own state. It is read and never written,
# so its checksum must survive a --check.
karabiner_before="$(/usr/bin/cksum <"$full_home/.config/karabiner/karabiner.json")"
plan_status "$full_home" --check >/dev/null
assert_equal "$karabiner_before" "$(/usr/bin/cksum <"$full_home/.config/karabiner/karabiner.json")" \
  'plan.sh must never modify karabiner.json'

# The bar pinned to a workspace list AeroSpace does not run: three chips for
# thirteen workspaces is exactly the disagreement nothing used to notice.
drift_home="$(new_full_home)"
printf 'SKETCHYBAR_WORKSPACES="1 2 3"\n' >>"$drift_home/.config/sketchybar/theme.conf"
drift_plan="$(in_home "$drift_home" "$drift_home/.config/aerospace/plan.sh")"
assert_output_matches "$drift_plan" 'drift .*SketchyBar would show \[1 2 3\]' \
  'a bar pinned to a different workspace list must be reported'
assert_equal '1' "$(plan_status "$drift_home" --check)" \
  'cross-tool disagreement alone must fail --check'
assert_equal '0' "$(plan_status "$drift_home")" \
  'cross-tool disagreement must still leave the plain report at exit 0'

# A profile that moves the stage role without editing workspaces.conf: AeroSpace
# stages on 8, Recording Mode still reads 13 out of the file.
stage_home="$(new_full_home)"
cat >"$stage_home/.config/ai-first/profile.conf" <<'EOF'
AI_FIRST_PRESET="custom"
AEROSPACE_MAIN_WORKSPACES="1 2 3 4 5 6"
AEROSPACE_SIDE_WORKSPACES="7 9 10 11 12"
AEROSPACE_STAGE_WORKSPACES="8"
EOF
stage_plan="$(in_home "$stage_home" "$stage_home/.config/aerospace/plan.sh")"
assert_output_matches "$stage_plan" 'drift .*Recording Mode would park on workspace 13, outside the stage group \[8\]' \
  'a stage role that only the profile knows about must be reported'

# A Karabiner install whose complex modification was never deployed is a choice,
# not a fault: Karabiner-Elements creates that directory by itself.
karabiner_home="$(new_full_home)"
rm -f "$karabiner_home/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json"
karabiner_plan="$(in_home "$karabiner_home" "$karabiner_home/.config/aerospace/plan.sh")"
assert_output_matches "$karabiner_plan" 'note .*complex modification is not deployed' \
  'a missing Karabiner asset must be reported'
assert_equal '0' "$(plan_status "$karabiner_home" --check)" \
  'a Karabiner rule nobody enabled must not fail --check'

# Importing a rule set through Karabiner's UI prefixes every rule with the set's
# title, so a machine with all seven rules live carries them as "CapsLock AI
# Lite - Navigation" rather than "Navigation". Matching the description exactly
# reported 0 of 7 on the author's own machine while all seven were running -
# the fixture in this repo never caught it because its karabiner.json is the one
# this repo ships, where the names line up by construction.
rename_karabiner_rules() {
  local home_dir="$1" prefix="$2"
  /usr/bin/sed -e "s/\"description\": \"/\"description\": \"$prefix/" \
    "$home_dir/.config/karabiner/karabiner.json" >"$home_dir/karabiner.renamed" &&
    mv "$home_dir/karabiner.renamed" "$home_dir/.config/karabiner/karabiner.json"
}

prefixed_home="$(new_full_home)"
rename_karabiner_rules "$prefixed_home" 'CapsLock AI Lite - '
prefixed_plan="$(in_home "$prefixed_home" "$prefixed_home/.config/aerospace/plan.sh")"
assert_output_matches "$prefixed_plan" 'ok .*Karabiner: all [0-9]+ shipped rule' \
  'rules imported under the set title must still be recognised'

# The separator is what makes that safe. Without it this would be a substring
# match, and an unrelated rule that merely contains a shipped name would be
# reported as the shipped rule.
substring_home="$(new_full_home)"
rename_karabiner_rules "$substring_home" 'Reverse '
substring_plan="$(in_home "$substring_home" "$substring_home/.config/aerospace/plan.sh")"
assert_output_matches "$substring_plan" 'note .*0 of [0-9]+ shipped rule' \
  'a rule that merely contains a shipped name must not count as that rule'

# --- "none" has to mean none -------------------------------------------------

layout_of() {
  local home_dir="$1" pack="$2" app_id="$3" app_name="$4"
  env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u AEROSPACE_CONFIG_DIR \
      "HOME=$home_dir" "AI_FIRST_ROUTING_PACK=$pack" "$system_bash" -c '
    . "$HOME/.config/aerospace/app-defaults.sh"
    if should_float_window "$1" "$2" "$3"; then
      printf floating
    elif should_tile_window "$1" "$2" "$3"; then
      printf tiling
    else
      printf none
    fi
  ' _ "$app_id" "$app_name" "${5:-}" 2>/dev/null || true
}

pack_home="$(new_bare_home)"

# Third-party app identity, which is what moved out of the code.
assert_equal 'none' "$(layout_of "$pack_home" none com.lbyczf.clashwin 'Clash for Windows')" \
  'the none pack must not force a layout on the author-s VPN client'
assert_equal 'none' "$(layout_of "$pack_home" none com.tencent.xinWeChat 'WeChat')" \
  'the none pack must not force a layout on a chat app'
assert_equal 'none' "$(layout_of "$pack_home" none com.spotify.client 'Spotify')" \
  'the none pack must not force a layout on a media player'
assert_equal 'none' "$(layout_of "$pack_home" none now.typeless.desktop 'Typeless')" \
  'the none pack must not force a layout on a dictation utility'

# The author's desk is opt-in and must still be exactly the author's desk.
assert_equal 'floating' "$(layout_of "$pack_home" author com.lbyczf.clashwin 'Clash for Windows')" \
  'the author pack must still float the author-s VPN client'
assert_equal 'floating' "$(layout_of "$pack_home" author com.spotify.client 'Spotify')" \
  'the author pack must still float Spotify'
assert_equal 'floating' "$(layout_of "$pack_home" author com.tencent.xinWeChat 'WeChat')" \
  'the author pack must still float WeChat'

# The public pack carries the widely used apps and none of the private ones.
assert_equal 'floating' "$(layout_of "$pack_home" suggested com.tencent.xinWeChat 'WeChat')" \
  'the suggested pack must float a widely used chat app'
assert_equal 'floating' "$(layout_of "$pack_home" suggested com.bilibili.bilibiliPC 'Bilibili')" \
  'the suggested pack must float a widely used media app'
assert_equal 'none' "$(layout_of "$pack_home" suggested com.lbyczf.clashwin 'Clash for Windows')" \
  'the suggested pack must not carry one person-s private toolbox'

# What stays in the code is about the kind of window, not the identity of an
# app, and it applies to everyone whatever pack they chose.
assert_equal 'floating' "$(layout_of "$pack_home" none com.example.Anything 'Anything' 'Settings')" \
  'a settings dialog must float on every install'
assert_equal 'floating' "$(layout_of "$pack_home" none com.example.Anything 'Anything' '偏好设置')" \
  'a settings dialog must float whatever language it is titled in'
assert_equal 'floating' "$(layout_of "$pack_home" none com.jetbrains.goland 'GoLand' 'Refactor this')" \
  'a JetBrains dialog must float on every install'
assert_equal 'tiling' "$(layout_of "$pack_home" none com.jetbrains.goland 'GoLand')" \
  'a JetBrains main window must tile on every install'
assert_equal 'floating' "$(layout_of "$pack_home" none com.apple.finder 'Finder')" \
  'a macOS utility surface must float on every install'
assert_equal 'floating' "$(layout_of "$pack_home" none com.apple.Preview 'Preview')" \
  'Preview must float on every install'
assert_equal 'tiling' "$(layout_of "$pack_home" none com.google.Chrome 'Google Chrome')" \
  'a browser is a work window and must tile on every install'

# --- capture-current has to admit what it dropped ----------------------------
#
# The filter is load-bearing - `|` in an app name breaks the record format and a
# workspace with a space renders a command AeroSpace cannot run - but dropping
# those windows without saying so made the proposal look complete.

capture_home="$(new_bare_home)"
windows_file="$sandbox_root/windows.tsv"
tab="$(printf '\t')"
{
  printf 'xcom.tencent.xinWeChat%s微信%s10%sfloating\n' "$tab" "$tab" "$tab"
  printf 'xcom.evil.pipe%sEvil|Pipe%s3%stiling\n' "$tab" "$tab" "$tab"
  printf 'x%sSpaced Workspace%smy ws%stiling\n' "$tab" "$tab" "$tab"
} >"$windows_file"

capture_out="$(env -u XDG_CONFIG_HOME -u AEROSPACE_CONFIG_DIR "HOME=$capture_home" \
  "AEROSPACE_CAPTURE_WINDOWS_FILE=$windows_file" "APP_ROUTE_NOTIFY=0" \
  "$system_bash" "$capture_home/.config/aerospace/app-route.sh" capture-current 2>&1 || true)"
assert_contains "$capture_out" '2 window(s) ignored: unusable app name or workspace.' \
  'the preview must say how many windows it could not turn into a route'
assert_contains "$capture_out" 'com.tencent.xinWeChat' \
  'the windows it could use must still be proposed'
assert_not_contains "$capture_out" 'Evil|Pipe' \
  'an app name holding a field separator must still be kept out of the route file'

clean_windows="$sandbox_root/clean-windows.tsv"
printf 'xcom.tencent.xinWeChat%s微信%s10%sfloating\n' "$tab" "$tab" "$tab" >"$clean_windows"
clean_capture="$(env -u XDG_CONFIG_HOME -u AEROSPACE_CONFIG_DIR "HOME=$capture_home" \
  "AEROSPACE_CAPTURE_WINDOWS_FILE=$clean_windows" "APP_ROUTE_NOTIFY=0" \
  "$system_bash" "$capture_home/.config/aerospace/app-route.sh" capture-current 2>&1 || true)"
assert_not_contains "$clean_capture" 'window(s) ignored' \
  'a capture that dropped nothing must not report a count'

# --- CJK names must not shift the columns ------------------------------------
#
# Both tables now end with the one field that can hold wide characters, so
# everything before it is ASCII and lines up. Comparing the width of the part in
# front of the app name is the whole assertion.

column_home="$(new_bare_home)"
cat >"$column_home/.config/aerospace/app-routes.conf" <<'EOF'
name|Ascii App|communication|fixed|floating
name|微信|communication|fixed|floating
name|哔哩哔哩|communication|fixed|floating
EOF

prefix_width() {
  local haystack="$1" app="$2" row=''
  row="$(printf '%s\n' "$haystack" | /usr/bin/grep -- " $app\$" | /usr/bin/head -n 1)"
  row="${row%"$app"}"
  printf '%s' "${#row}"
}

list_out="$(env -u XDG_CONFIG_HOME -u AEROSPACE_CONFIG_DIR "HOME=$column_home" "APP_ROUTE_NOTIFY=0" \
  "$system_bash" "$column_home/.config/aerospace/app-route.sh" list 2>&1 || true)"
assert_output_matches "$list_out" ' 微信$' \
  'app-route.sh list must end each row with the app name, the one field that can be wide'
assert_equal "$(prefix_width "$list_out" 'Ascii App')" "$(prefix_width "$list_out" '微信')" \
  'app-route.sh list must keep its columns when an app name is CJK'
assert_equal "$(prefix_width "$list_out" 'Ascii App')" "$(prefix_width "$list_out" '哔哩哔哩')" \
  'app-route.sh list must keep its columns for a four-character CJK app name'

column_plan="$(in_home "$column_home" "$column_home/.config/aerospace/plan.sh")"
assert_output_matches "$column_plan" ' 微信$' \
  'plan.sh must end each route row with the app name, the one field that can be wide'
assert_equal "$(prefix_width "$column_plan" 'Ascii App')" "$(prefix_width "$column_plan" '微信')" \
  'plan.sh route rows must keep their columns when an app name is CJK'
assert_equal "$(prefix_width "$column_plan" 'Ascii App')" "$(prefix_width "$column_plan" '哔哩哔哩')" \
  'plan.sh route rows must keep their columns for a four-character CJK app name'

smoke_summary "$(basename "$0")"
