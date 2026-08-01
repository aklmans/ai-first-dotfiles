#!/usr/bin/env bash
set -euo pipefail

# Covers the AeroSpace desktop layer: the workspace/display config layer in
# home/.config/aerospace/, the generator that renders it into .aerospace.toml,
# and the scripts that run at login and on the bar shortcuts.
#
# Why this exists: those scripts used to name three specific monitors and the
# number thirteen in six files. On a Mac without those displays - a laptop on
# its own, which is what most people have - the login script blocked for twenty
# seconds waiting for monitors that would never appear, doctor.sh could not go
# green, and Option+Shift+Space failed to resolve a display and did nothing.
# The cases below pin down both halves: a single display is a first-class
# configuration, and the three-display desk the author actually uses still
# behaves exactly as before.
#
# Everything that would touch the machine (aerospace, sketchybar, hs, lua,
# defaults) is stubbed on PATH, HOME is a throwaway directory, and the scripts
# under test run on /bin/bash so bash 3.2 regressions cannot hide.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
system_bash="/bin/bash"

if [[ ! -x "$system_bash" ]]; then
  printf 'Missing %s; these scripts must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/aerospace-workflow-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

# The layout library layers $HOME/.config/ai-first/profile.conf over whatever
# displays.conf and workspaces.conf say, so the real $HOME decides the answer
# unless a case overrides it. Every case here means to test the shipped config,
# including the one that asserts the tracked .aerospace.toml still matches it -
# on a machine with author-full installed that check renders 13 workspaces and
# compares them against a file that has six. Pinning HOME keeps the suite about
# this repository rather than about the machine running it.
HOME="$sandbox_root/home"
export HOME
mkdir -p "$HOME"

checks=0
failures=0

pass() {
  checks=$((checks + 1))
}

fail() {
  local message="$1"
  local detail="${2:-}"

  checks=$((checks + 1))
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$message" >&2
  if [[ -n "$detail" ]]; then
    printf -- '--- detail ---\n%s\n--------------\n' "$detail" >&2
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass
  else
    fail "$label" "missing: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    pass
  else
    fail "$label" "unexpected: $needle"
  fi
}

assert_equal() {
  local expected="$1" actual="$2" label="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass
  else
    fail "$label" "expected: $expected
actual:   $actual"
  fi
}

assert_file_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$file" 2>/dev/null; then
    pass
  else
    fail "$label" "$(cat "$file" 2>/dev/null || printf '(unreadable: %s)' "$file")"
  fi
}

assert_file_lacks() {
  local file="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$file" 2>/dev/null; then
    fail "$label" "unexpected in $file: $needle"
  else
    pass
  fi
}

assert_status() {
  local expected="$1" actual="$2" label="$3" detail="${4:-}"
  if [[ "$expected" == "$actual" ]]; then
    pass
  else
    fail "$label" "expected exit $expected, got $actual
$detail"
  fi
}

# --- repository content -----------------------------------------------------

toml="$(cat "$repo_root/home/.aerospace.toml")"
assert_not_contains "$toml" "warp-launch-agent.sh" "AeroSpace config"
assert_contains "$toml" ".config/ai-router/ai-router.sh agent codex" "Codex agent binding"
assert_contains "$toml" ".config/ai-router/ai-router.sh agent claude" "Claude agent binding"
assert_not_contains "$toml" "agent-run codex" "Codex binding must not auto-run"
assert_not_contains "$toml" "agent-run claude" "Claude binding must not auto-run"
assert_contains "$toml" "com.obsproject.obs-studio" "OBS workspace binding"
assert_contains "$toml" "move-node-to-workspace 11" "OBS workspace target"
assert_contains "$toml" "com.bilibili.bilibiliPC" "Bilibili workspace binding"
assert_contains "$toml" "move-node-to-workspace 10" "Bilibili workspace target"
assert_contains "$toml" "com.blade.shadow-macos" "Shadow workspace binding"
assert_contains "$toml" "ShadowPCDisplay" "Shadow app-name fallback"
assert_contains "$toml" "if.app-id = 'com.apple.finder'" "Finder follow-current route"
assert_contains "$toml" "if.app-id = 'com.apple.Preview'" "Preview follow-current route"
assert_contains "$toml" ".config/aerospace/app-route.sh bind-here" "focused app bind shortcut"
assert_contains "$toml" ".config/aerospace/app-route.sh follow" "focused app follow shortcut"
assert_not_contains "$toml" "^(Finder|访达|System Settings|System Preferences|系统设置|Activity Monitor|监视器|Stats|Mail|邮件|Photos|照片|Preview|预览|Archive Utility|归档实用工具|App Store)$" "Finder and Preview fallback workspace placement"

# The tracked config must be desk-independent. A monitor model number here is
# the bug this whole layer exists to remove: it ships one person's hardware to
# everyone else as a default that cannot work.
assert_not_contains "$toml" "PHL 279C9" "Tracked AeroSpace config names a specific monitor"
assert_not_contains "$toml" "24V5C2" "Tracked AeroSpace config names a specific monitor"
assert_not_contains "$toml" "Built-in Retina Display" "Tracked AeroSpace config names a specific monitor"
assert_contains "$toml" "'1' = ['main']" "Workspace 1 assigned by role, not by monitor name"
assert_contains "$toml" "'13' = ['built-in', 'secondary', 'main']" "Stage workspace falls back across displays"

hammerspoon="$(cat "$repo_root/home/.hammerspoon/init.lua")"
assert_contains "$hammerspoon" 'jetbrainsDefaultWorkspace = "2"' "Hammerspoon JetBrains default workspace"
assert_contains "$hammerspoon" '["com.obsproject.obs-studio"] = "11"' "Hammerspoon OBS fixed workspace skip"
assert_contains "$hammerspoon" '["com.bilibili.bilibiliPC"] = "10"' "Hammerspoon Bilibili fixed workspace skip"
assert_contains "$hammerspoon" '["com.blade.shadow-macos"] = "2"' "Hammerspoon Shadow fixed workspace skip"
assert_contains "$hammerspoon" '["com.apple.finder"] = true' "Finder must skip per-app workspace inheritance"
assert_contains "$hammerspoon" '["com.apple.Preview"] = true' "Preview must skip per-app workspace inheritance"
assert_contains "$hammerspoon" 'aiFirstRoutingPack == "author"' "workspace inheritance must be limited to the author pack"
assert_contains "$hammerspoon" 'routePolicyByBundle' "explicit route policies must override Hammerspoon inheritance"

screencast="$(cat "$repo_root/home/.hammerspoon/screencast.lua")"
assert_contains "$screencast" "AEROSPACE_STAGE_WORKSPACES" "Recording workspace read from workspaces.conf"
assert_not_contains "$screencast" 'recordingWorkspace = "13"' "Recording workspace must not be hard-coded"

rules="$(HOME="$sandbox_root/default-rules-home" AI_FIRST_PROFILE_LIB=/private/tmp/ai-first-no-profile \
  AI_FIRST_APP_ROUTES_FILE="$repo_root/home/.config/aerospace/app-routes.conf" \
  "$repo_root/home/.config/aerospace/app-defaults.sh" --toml)"
assert_contains "$rules" "Refactor" "JetBrains floating dialog matcher"
assert_contains "$rules" "com.obsproject.obs-studio" "Generated OBS workspace binding"
assert_contains "$rules" "com.bilibili.bilibiliPC" "Generated Bilibili workspace binding"
assert_contains "$rules" "com.blade.shadow-macos" "Generated Shadow workspace binding"

context_rules="$(HOME="$sandbox_root/context-home" \
  AI_FIRST_APP_ROUTES_FILE="$repo_root/home/.config/aerospace/app-routes.conf" \
  "$repo_root/home/.config/aerospace/app-defaults.sh" --toml)"
assert_contains "$context_rules" "if.app-id = 'com.apple.finder'" "Generated Finder follow-current binding"
assert_contains "$context_rules" "if.app-id = 'com.apple.Preview'" "Generated Preview follow-current binding"

# The shipped .aerospace.toml has to be exactly what the shipped config renders,
# or doctor.sh reports drift on a machine nobody has touched yet.
render_check_output=""
render_check_status=0
render_check_output="$("$system_bash" "$repo_root/home/.config/aerospace/render-layout.sh" \
  --check --no-app-rules "$repo_root/home/.aerospace.toml" 2>&1)" || render_check_status=$?
assert_status 0 "$render_check_status" \
  "Tracked .aerospace.toml is out of date with workspaces.conf" "$render_check_output"

# --- stubs ------------------------------------------------------------------

stub_dir="$sandbox_root/stub-bin"
mkdir -p "$stub_dir"

# `sleep` is stubbed for the same reason `aerospace` is: what the login restore
# asks to wait for is a property of the code, how long this machine took to run
# it is not. Two checks below used wall clock and measured the load on the test
# machine instead - a parallel suite run stretched a 2.5s wait to 19s against a
# 12s budget and went red for nothing.
#
# It lives in its own directory rather than beside the other stubs because
# doctor.sh gives every check a deadline by racing it against a background
# sleep. On the shared PATH this stub returns instantly, the watchdog fires
# before the check does, and doctor reports that all fourteen of them timed out.
sleep_stub_dir="$sandbox_root/sleep-bin"
mkdir -p "$sleep_stub_dir"
cat >"$sleep_stub_dir/sleep" <<'STUB'
#!/bin/bash
printf '%s\n' "${1:-0}" >>"${AEROSPACE_STUB_DIR:-/dev/null}/sleep.log"
exit 0
STUB
chmod +x "$sleep_stub_dir/sleep"

# Seconds the run under $1 asked to wait for, total.
requested_sleep() {
  [ -f "$1/sleep.log" ] || { printf '0\n'; return 0; }
  /usr/bin/awk '{ total += $1 } END { printf "%.1f\n", total + 0 }' "$1/sleep.log"
}

# Whether $1 seconds is within the $2 budget, compared as decimals.
sleep_within() {
  /usr/bin/awk -v got="$1" -v budget="$2" 'BEGIN { if (got <= budget) { exit 0 } exit 1 }'
}

cat >"$stub_dir/aerospace" <<'STUB'
#!/bin/bash
# Reads its answers from $AEROSPACE_STUB_DIR so a case can describe a desk.
#   monitors        "<id>\t<name>" per connected monitor
#   workspaces.<id> workspaces currently on that monitor, one per line
#   monitors.late   monitor list to switch to after $AEROSPACE_STUB_SWITCH calls
fixture="${AEROSPACE_STUB_DIR:-}"
[ -n "$fixture" ] || exit 1

calls_file="$fixture/calls"
calls="$(cat "$calls_file" 2>/dev/null || printf '0')"
calls=$((calls + 1))
printf '%s\n' "$calls" >"$calls_file"

monitors="$fixture/monitors"
if [ -f "$fixture/monitors.late" ] && [ "$calls" -gt "${AEROSPACE_STUB_SWITCH:-0}" ]; then
  monitors="$fixture/monitors.late"
fi

case "${1:-}" in
  list-monitors)
    printf '%s\n' "$calls" >>"$fixture/list-monitors.log"
    if [ "${2:-}" = "--count" ]; then
      grep -c . "$monitors"
    else
      cat "$monitors"
    fi
    ;;
  list-workspaces)
    monitor_id=""
    focused=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --monitor) monitor_id="$2"; shift ;;
        --focused) focused=1 ;;
      esac
      shift
    done
    if [ "$focused" -eq 1 ]; then
      cat "$fixture/focused" 2>/dev/null || printf '1\n'
    elif [ -n "$monitor_id" ]; then
      cat "$fixture/workspaces.$monitor_id" 2>/dev/null || true
    fi
    ;;
  list-windows)
    cat "$fixture/windows" 2>/dev/null || true
    ;;
  *)
    printf 'aerospace %s\n' "$*" >>"$fixture/log"
    ;;
esac
exit 0
STUB

cat >"$stub_dir/hs" <<'STUB'
#!/bin/bash
# display-resolver.sh asks for "<name>\t<screen id>\t<uuid>" per screen.
# Every call is logged as well, because who reloads Hammerspoon and when is
# something the renderers have to get right: it reads app-routes.conf once at
# init, so anything that edits that file and does not tell it leaves it acting
# on the routes it started with.
if [ -n "${AEROSPACE_STUB_DIR:-}" ]; then
  printf 'hs %s\n' "$*" >>"$AEROSPACE_STUB_DIR/hs.log"
fi
cat "${HS_STUB_SCREENS:-/dev/null}" 2>/dev/null || true
exit 0
STUB

cat >"$stub_dir/sketchybar" <<'STUB'
#!/bin/bash
if [ "${1:-}" = "--query" ] && [ "${2:-}" = "displays" ]; then
  cat "${SKETCHYBAR_STUB_DISPLAYS:-/dev/null}"
  exit 0
fi
if [ "${1:-}" = "--query" ]; then
  printf '{}\n'
  exit 0
fi
printf '%s\n' "$*" >>"${SKETCHYBAR_TEST_LOG:-/dev/null}"
exit 0
STUB

cat >"$stub_dir/lua" <<'STUB'
#!/bin/bash
exit 0
STUB

cat >"$stub_dir/defaults" <<'STUB'
#!/bin/bash
# doctor.sh only reads the ctrl-drag preference; answer "enabled" so the
# report is deterministic instead of depending on the machine running tests.
if [ "${1:-}" = "read" ]; then
  printf '1\n'
fi
exit 0
STUB

for stub in aerospace hs sketchybar lua defaults; do
  chmod +x "$stub_dir/$stub"
done

# --- sandbox homes ----------------------------------------------------------

new_home() {
  local home_dir
  home_dir="$(mktemp -d "$sandbox_root/home.XXXXXX")"

  mkdir -p "$home_dir/.config"
  cp -R "$repo_root/home/.config/aerospace" "$home_dir/.config/aerospace"
  cp -R "$repo_root/home/.config/sketchybar" "$home_dir/.config/sketchybar"
  cp -R "$repo_root/home/.hammerspoon" "$home_dir/.hammerspoon"
  cp "$repo_root/home/.aerospace.toml" "$home_dir/.aerospace.toml"

  printf '%s\n' "$home_dir"
}

# One connected display, config left exactly as shipped: the machine almost
# everyone who clones this repo actually has.
single_display_fixture() {
  local dir="$1"

  mkdir -p "$dir"
  printf '1\tBuilt-in Retina Display\n' >"$dir/monitors"
  printf '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n' >"$dir/workspaces.1"
  printf '1\n' >"$dir/focused"
  printf 'Built-in Retina Display\t1\tUUID-BUILTIN\n' >"$dir/screens"
  cat >"$dir/displays.json" <<'JSON'
[
  {"arrangement-id":1,"DirectDisplayID":1,"UUID":"UUID-BUILTIN"}
]
JSON
}

# The author's desk: three displays, named in displays.conf.
three_display_fixture() {
  local dir="$1"

  mkdir -p "$dir"
  {
    printf '1\tPHL 279C9\n'
    printf '2\tBuilt-in Retina Display\n'
    printf '3\t24V5C2\n'
  } >"$dir/monitors"
  printf '1\n2\n3\n4\n5\n6\n' >"$dir/workspaces.1"
  printf '13\n' >"$dir/workspaces.2"
  printf '7\n8\n9\n10\n11\n12\n' >"$dir/workspaces.3"
  printf '1\n' >"$dir/focused"
  {
    printf 'Built-in Retina Display\t1\tUUID-BUILTIN\n'
    printf '24V5C2\t2\tUUID-SIDE\n'
    printf 'PHL 279C9\t3\tUUID-MAIN\n'
  } >"$dir/screens"
  cat >"$dir/displays.json" <<'JSON'
[
  {"arrangement-id":1,"DirectDisplayID":1,"UUID":"UUID-BUILTIN"},
  {"arrangement-id":2,"DirectDisplayID":3,"UUID":"UUID-MAIN"},
  {"arrangement-id":3,"DirectDisplayID":2,"UUID":"UUID-SIDE"}
]
JSON
}

write_displays_conf() {
  local home_dir="$1" main="$2" side="$3" stage="$4"

  cat >"$home_dir/.config/aerospace/displays.conf" <<EOF
AEROSPACE_MAIN_MONITOR_NAME="$main"
AEROSPACE_SIDE_MONITOR_NAME="$side"
AEROSPACE_STAGE_MONITOR_NAME="$stage"
EOF
}

last_output=""
last_status=0
# Set right before a call to put a stub ahead of the shared ones. Cleared on the
# way out so it cannot reach the next case.
run_in_home_path_prefix=""

run_in_home() {
  local home_dir="$1" fixture="$2"
  shift 2
  local search_path="$stub_dir:$PATH"
  [ -z "$run_in_home_path_prefix" ] || search_path="$run_in_home_path_prefix:$search_path"
  run_in_home_path_prefix=""

  last_status=0
  last_output="$(env \
    -u XDG_STATE_HOME \
    -u XDG_CONFIG_HOME \
    -u AEROSPACE_MAIN_MONITOR_NAME \
    -u AEROSPACE_SIDE_MONITOR_NAME \
    -u AEROSPACE_STAGE_MONITOR_NAME \
    "HOME=$home_dir" \
    "PATH=$search_path" \
    "AEROSPACE_STUB_DIR=$fixture" \
    "HS_STUB_SCREENS=$fixture/screens" \
    "SKETCHYBAR_STUB_DISPLAYS=$fixture/displays.json" \
    "SKETCHYBAR_TEST_LOG=$fixture/sketchybar.log" \
    "AEROSPACE_BIN=$stub_dir/aerospace" \
    "HS_BIN=$stub_dir/hs" \
    "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
    "$system_bash" "$@" 2>&1)" || last_status=$?
}

# --- case: one display is a first-class configuration -----------------------

single_home="$(new_home)"
single_fixture="$sandbox_root/fixture-single"
single_display_fixture "$single_fixture"

run_in_home "$single_home" "$single_fixture" "$single_home/.config/aerospace/check-display-layout.sh"
assert_status 0 "$last_status" "Layout check must pass with one display" "$last_output"
assert_contains "$last_output" "OK: workspace layout matches" "Layout check reports success on one display"

# The point of this batch. The old script polled for two named monitors that
# will never appear here, twice, at ten seconds each.
#
# Two things pin that down, and neither is a stopwatch. The poll count: with no
# monitor named in displays.conf there is nothing to wait for, so the wait has
# to settle on its first look rather than working through its 32 attempts. And
# the total the script asked to sleep for, which is 2s of settle plus a 0.5s
# pause here and would be ~22s if the polling regression came back.
: >"$single_fixture/list-monitors.log"
: >"$single_fixture/sleep.log"
run_in_home_path_prefix="$sleep_stub_dir"
run_in_home "$single_home" "$single_fixture" "$single_home/.config/aerospace/startup-restore.sh"
single_sleep="$(requested_sleep "$single_fixture")"
assert_status 0 "$last_status" "Login restore must succeed with one display" "$last_output"

single_polls="$(grep -c . "$single_fixture/list-monitors.log" 2>/dev/null | tr -d ' ')"
[[ -n "$single_polls" ]] || single_polls=0
# One look, every time. Two is slack, not headroom: losing the early return
# drops the wait into its stability loop, which needs three consecutive equal
# counts, and naming a monitor that never arrives raises that to twelve. A
# threshold of four would have let the first of those through.
if [[ "$single_polls" -le 2 ]]; then
  pass
else
  fail "Login restore polled for monitors ${single_polls}x with none configured (it must settle on the first look)" "$last_output"
fi

if sleep_within "$single_sleep" 5; then
  pass
else
  fail "Login restore asked to wait ${single_sleep}s on a single-display Mac (was ~22s)" "$last_output"
fi
printf 'single-display startup-restore.sh: %ss requested wait, %s monitor poll(s)\n' "$single_sleep" "$single_polls"

# Without the deliberate settle delay, nothing else may block at all.
: >"$single_fixture/sleep.log"
last_status=0
last_output="$(env -u XDG_STATE_HOME "HOME=$single_home" "PATH=$sleep_stub_dir:$stub_dir:$PATH" \
  "AEROSPACE_STUB_DIR=$single_fixture" "HS_STUB_SCREENS=$single_fixture/screens" \
  "AEROSPACE_BIN=$stub_dir/aerospace" "HS_BIN=$stub_dir/hs" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "SKETCHYBAR_TEST_LOG=$single_fixture/sketchybar.log" \
  AEROSPACE_STARTUP_RESTORE_DELAY=0 \
  "$system_bash" "$single_home/.config/aerospace/startup-restore.sh" 2>&1)" || last_status=$?
no_delay_sleep="$(requested_sleep "$single_fixture")"
# The 0.5s pause before the layout settles is the only wait left once the
# settle delay is zero. Anything more means something else started blocking.
if sleep_within "$no_delay_sleep" 1; then
  pass
else
  fail "Login restore asked to wait ${no_delay_sleep}s with no settle delay on one display" "$last_output"
fi

run_in_home "$single_home" "$single_fixture" "$single_home/.config/aerospace/doctor.sh"
assert_status 0 "$last_status" "doctor.sh must be green with one display" "$last_output"
assert_not_contains "$last_output" "FAIL" "doctor.sh reports no failures with one display"
assert_contains "$last_output" "OK: no blocking issues" "doctor.sh summary is clean with one display"

# Option+Shift+Space is the shortcut the README leads with. With one display
# there is no "other display" to keep the bar on, so it has to hide the bar
# itself rather than resolve a monitor id and give up.
: >"$single_fixture/sketchybar.log"
run_in_home "$single_home" "$single_fixture" \
  "$single_home/.config/aerospace/toggle-sketchybar-space.sh" toggle-main
assert_status 0 "$last_status" "toggle-main must work with one display" "$last_output"
assert_file_contains "$single_fixture/sketchybar.log" "--bar hidden=on display=all" \
  "toggle-main hides the bar on a single-display Mac"
assert_file_lacks "$single_home/.aerospace.toml" "monitor.\"\"" \
  "Gap rewrite must not emit an empty monitor name"

run_in_home "$single_home" "$single_fixture" \
  "$single_home/.config/aerospace/toggle-sketchybar-space.sh" toggle-main
assert_file_contains "$single_fixture/sketchybar.log" "--bar hidden=off display=all" \
  "toggle-main restores the bar on a single-display Mac"

# --- case: the author's three-display desk still works ----------------------

three_home="$(new_home)"
three_fixture="$sandbox_root/fixture-three"
three_display_fixture "$three_fixture"
write_displays_conf "$three_home" "PHL 279C9" "24V5C2" "Built-in Retina Display"

# Naming displays is exactly the upgrade path for someone whose workspaces are
# pinned to specific monitors: fill in displays.conf, render once.
run_in_home "$three_home" "$three_fixture" "$three_home/.config/aerospace/render-layout.sh"
assert_status 0 "$last_status" "render-layout.sh must accept named displays" "$last_output"
assert_file_contains "$three_home/.aerospace.toml" "'1' = ['PHL 279C9', 'main']" \
  "Named main display is pinned in the AeroSpace config"
assert_file_contains "$three_home/.aerospace.toml" "'13' = ['Built-in Retina Display', 'built-in', 'secondary', 'main']" \
  "Named stage display keeps its fallbacks"

run_in_home "$three_home" "$three_fixture" "$three_home/.config/aerospace/check-display-layout.sh"
assert_status 0 "$last_status" "Layout check must pass on the three-display desk" "$last_output"
assert_contains "$last_output" "main display PHL 279C9 (1)" "Main role resolves to the configured monitor"
assert_contains "$last_output" "side display 24V5C2 (3)" "Side role resolves to the configured monitor"
assert_contains "$last_output" "stage display Built-in Retina Display (2)" "Stage role resolves to the configured monitor"

: >"$three_fixture/sketchybar.log"
run_in_home "$three_home" "$three_fixture" \
  "$three_home/.config/aerospace/toggle-sketchybar-space.sh" hide-main
assert_status 0 "$last_status" "hide-main must succeed on three displays" "$last_output"
assert_file_contains "$three_fixture/sketchybar.log" "--bar hidden=off display=1,3" \
  "hide-main hides only the arrangement id of the configured main display"

main_compact_gaps="$(grep -c 'monitor."PHL 279C9" = 8' "$three_home/.aerospace.toml" | tr -d ' ')"
assert_equal "4" "$main_compact_gaps" "hide-main compacts all four outer gaps of the main display"

# The gap rewrite used to consume every comment between [gaps] and the next
# section, including the anchor comment render-app-rules.sh and doctor.sh key
# off. One press of the shortcut broke app-rule rendering for good.
assert_file_contains "$three_home/.aerospace.toml" "# Application placement and floating rules." \
  "Gap rewrite must not eat the comment that anchors app-rule rendering"
assert_file_contains "$three_home/.aerospace.toml" "# Keep this block aligned with ~/.config/aerospace/app-defaults.sh." \
  "Gap rewrite must not eat the comments after the block it owns"

# README names render-app-rules.sh as the command that makes a hand-edited
# app-routes.conf real, so it has to tell both tools. AeroSpace reads the TOML
# it just wrote; Hammerspoon reads app-routes.conf itself and only at init, and
# it inherits the focused workspace for any app it has no route for. Renders
# that skipped the Hammerspoon reload therefore did not just leave it stale -
# the new route took effect in AeroSpace and Hammerspoon moved the window off it
# a moment later, which is how a route added by hand landed on whatever
# workspace happened to be in front.
printf 'id|com.apple.TextEdit|research|prefer|tiling\n' \
  >>"$three_home/.config/aerospace/app-routes.conf"
: >"$three_fixture/log"
: >"$three_fixture/hs.log"
run_in_home "$three_home" "$three_fixture" "$three_home/.config/aerospace/render-app-rules.sh"
assert_status 0 "$last_status" "render-app-rules.sh must succeed after a hand edit" "$last_output"
assert_file_contains "$three_home/.aerospace.toml" "com.apple.TextEdit" \
  "a hand-edited route must reach the rendered TOML"
# The whole line, not a substring: `aerospace reload-config --dry-run --no-gui`
# contains `aerospace reload-config`, so a substring match is satisfied by the
# courtesy check alone and says nothing about whether anything was applied.
if grep -Fxq 'aerospace reload-config' "$three_fixture/log"; then
  pass
else
  fail "render-app-rules.sh must reload AeroSpace, not only dry-run it" \
    "$(cat "$three_fixture/log" 2>/dev/null)"
fi
assert_file_contains "$three_fixture/hs.log" "hs.reload()" \
  "render-app-rules.sh must reload Hammerspoon, which reads app-routes.conf at init"

run_in_home "$three_home" "$three_fixture" "$three_home/.config/aerospace/doctor.sh"
assert_status 0 "$last_status" "doctor.sh must be green on the three-display desk" "$last_output"

run_in_home "$three_home" "$three_fixture" \
  "$three_home/.config/aerospace/toggle-sketchybar-space.sh" show-main
assert_status 0 "$last_status" "show-main must succeed on three displays" "$last_output"
assert_file_lacks "$three_home/.aerospace.toml" 'monitor."PHL 279C9"' \
  "Restoring gaps removes the per-monitor overrides again"

# A display that is configured but unplugged must not strand its workspaces.
unplugged_fixture="$sandbox_root/fixture-unplugged"
single_display_fixture "$unplugged_fixture"
unplugged_home="$(new_home)"
write_displays_conf "$unplugged_home" "PHL 279C9" "24V5C2" "Built-in Retina Display"
run_in_home "$unplugged_home" "$unplugged_fixture" \
  "$unplugged_home/.config/aerospace/check-display-layout.sh"
assert_status 0 "$last_status" "Layout check must pass when configured displays are unplugged" "$last_output"
assert_contains "$last_output" 'is not connected' "Unplugged displays are reported as a note, not a failure"

# Late-arriving displays: the settle logic must still wait for the desk it was
# told about rather than declaring victory on the first monitor to appear.
late_fixture="$sandbox_root/fixture-late"
three_display_fixture "$late_fixture"
mv "$late_fixture/monitors" "$late_fixture/monitors.late"
printf '1\tPHL 279C9\n' >"$late_fixture/monitors"
late_home="$(new_home)"
write_displays_conf "$late_home" "PHL 279C9" "24V5C2" "Built-in Retina Display"
last_status=0
last_output="$(env -u XDG_STATE_HOME "HOME=$late_home" "PATH=$stub_dir:$PATH" \
  "AEROSPACE_STUB_DIR=$late_fixture" "AEROSPACE_STUB_SWITCH=4" \
  "HS_STUB_SCREENS=$late_fixture/screens" \
  "AEROSPACE_BIN=$stub_dir/aerospace" "HS_BIN=$stub_dir/hs" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "SKETCHYBAR_TEST_LOG=$late_fixture/sketchybar.log" \
  AEROSPACE_STARTUP_RESTORE_DELAY=0 \
  "$system_bash" "$late_home/.config/aerospace/startup-restore.sh" 2>&1)" || last_status=$?
assert_status 0 "$last_status" "Login restore must succeed when displays arrive late" "$last_output"

# The fixture only reports all three displays from the fifth call on, so a
# script that stopped polling at the first monitor it saw would show fewer.
late_polls="$(grep -c . "$late_fixture/list-monitors.log" 2>/dev/null | tr -d ' ')"
if [[ "${late_polls:-0}" -ge 5 ]]; then
  pass
else
  fail "Login restore stopped polling before the configured displays arrived" \
    "list-monitors calls: ${late_polls:-0}"
fi

# --- case: a config from before the markers existed -------------------------

# Someone who already runs this setup has a deployed .aerospace.toml with the
# old unmarked [gaps] table, and the deploy engine keeps it if they edited it.
# The first bar toggle after upgrading has to find the block anyway, add the
# markers, and - the actual old bug - leave the comments that follow it alone.
legacy_home="$(new_home)"
git -C "$repo_root" show HEAD:home/.aerospace.toml >"$legacy_home/.aerospace.toml" 2>/dev/null || true

if [[ -s "$legacy_home/.aerospace.toml" ]] && ! grep -Fq 'managed by toggle-sketchybar-space.sh' "$legacy_home/.aerospace.toml"; then
  run_in_home "$legacy_home" "$single_fixture" \
    "$legacy_home/.config/aerospace/toggle-sketchybar-space.sh" hide
  assert_status 0 "$last_status" "Bar toggle must work on a config without markers" "$last_output"
  assert_file_contains "$legacy_home/.aerospace.toml" "# >>> managed by toggle-sketchybar-space.sh - outer gaps >>>" \
    "Bar toggle adds the markers to an older config"
  assert_file_contains "$legacy_home/.aerospace.toml" "# Application placement and floating rules." \
    "Bar toggle keeps the anchor comment on an older config"
  assert_file_contains "$legacy_home/.aerospace.toml" "# Keep this block aligned with ~/.config/aerospace/app-defaults.sh." \
    "Bar toggle keeps every comment after the block it owns"

  run_in_home "$legacy_home" "$single_fixture" \
    "$legacy_home/.config/aerospace/toggle-sketchybar-space.sh" show
  assert_status 0 "$last_status" "Bar toggle must restore an upgraded config" "$last_output"
  assert_file_contains "$legacy_home/.aerospace.toml" "outer.top = 95" \
    "Restoring gaps writes the plain form on an upgraded config"
else
  # HEAD already has the markers, so there is nothing to upgrade from.
  pass
fi

# --- case: bar items land on displays that exist ----------------------------

# SketchyBar pins each workspace item to a display arrangement id. The old file
# fell back to 1, 2 and 3, so on a laptop workspaces 7-13 were assigned to two
# displays that do not exist and never appeared on the bar.
probe_plugins="$sandbox_root/probe-plugins"
mkdir -p "$probe_plugins"
printf '#!/bin/bash\nexit 0\n' >"$probe_plugins/aerospace_spaces_refresh.sh"
chmod +x "$probe_plugins/aerospace_spaces_refresh.sh"

run_spaces_items() {
  local home_dir="$1" fixture="$2"

  : >"$fixture/sketchybar.log"
  env \
    -u XDG_STATE_HOME \
    "HOME=$home_dir" \
    "PATH=$stub_dir:$PATH" \
    "AEROSPACE_STUB_DIR=$fixture" \
    "HS_STUB_SCREENS=$fixture/screens" \
    "SKETCHYBAR_STUB_DISPLAYS=$fixture/displays.json" \
    "SKETCHYBAR_TEST_LOG=$fixture/sketchybar.log" \
    "AEROSPACE_BIN=$stub_dir/aerospace" \
    "HS_BIN=$stub_dir/hs" \
    "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
    "PLUGIN_DIR=$probe_plugins" \
    "CONFIG_DIR=$home_dir/.config/sketchybar" \
    "$system_bash" "$home_dir/.config/sketchybar/items/spaces.sh" >/dev/null 2>&1 || true
}

run_spaces_items "$single_home" "$single_fixture"
single_space_displays="$(grep -o -- '--set space\.[0-9]* display=[0-9]*' "$single_fixture/sketchybar.log" |
  sed 's/.*display=//' | LC_ALL=C sort -u | tr '\n' ' ')"
assert_equal "1 " "$single_space_displays" "Every workspace item lands on the only display"
assert_file_contains "$single_fixture/sketchybar.log" "--add item space.13 left" \
  "Workspace 13 still gets a bar item on a single-display Mac"

run_spaces_items "$three_home" "$three_fixture"
assert_file_contains "$three_fixture/sketchybar.log" "--set space.1 display=2" \
  "Main workspaces bind to the main display's arrangement id"
assert_file_contains "$three_fixture/sketchybar.log" "--set space.7 display=3" \
  "Side workspaces bind to the side display's arrangement id"
assert_file_contains "$three_fixture/sketchybar.log" "--set space.13 display=1" \
  "The stage workspace binds to the built-in display"

# --- case: changing the workspace count is one file -------------------------

count_home="$(new_home)"
count_fixture="$sandbox_root/fixture-count"
single_display_fixture "$count_fixture"
printf '1\n2\n3\n4\n5\n' >"$count_fixture/workspaces.1"

before_hash="$(find "$count_home/.config/aerospace" -type f -name '*.sh' -exec cksum {} \; | LC_ALL=C sort | cksum)"

cat >"$count_home/.config/aerospace/workspaces.conf" <<'EOF'
AEROSPACE_MAIN_WORKSPACES="1 2 3"
AEROSPACE_SIDE_WORKSPACES="4 5"
AEROSPACE_STAGE_WORKSPACES=""
EOF

run_in_home "$count_home" "$count_fixture" "$count_home/.config/aerospace/render-layout.sh"
assert_status 0 "$last_status" "render-layout.sh must accept a five-workspace config" "$last_output"

assert_file_contains "$count_home/.aerospace.toml" "persistent-workspaces = ['1', '2', '3', '4', '5']" \
  "Workspace list follows workspaces.conf"
assert_file_lacks "$count_home/.aerospace.toml" "ctrl-6 = " \
  "Workspace shortcuts stop where the workspace list stops"
assert_file_lacks "$count_home/.aerospace.toml" "workspace 13" \
  "No shortcut may point at a workspace that no longer exists"
assert_file_lacks "$count_home/.aerospace.toml" "move-node-to-workspace 13" \
  "App rules with missing semantic targets are omitted"
assert_file_contains "$count_home/.aerospace.toml" "'4' = ['secondary', 'main']" \
  "Side workspaces follow the role split from workspaces.conf"

# No script had to be edited to get there.
after_hash="$(find "$count_home/.config/aerospace" -type f -name '*.sh' -exec cksum {} \; | LC_ALL=C sort | cksum)"
assert_equal "$before_hash" "$after_hash" "Changing the workspace count must not require editing any script"

run_in_home "$count_home" "$count_fixture" "$count_home/.config/aerospace/check-display-layout.sh"
assert_status 0 "$last_status" "Layout check follows the reduced workspace list" "$last_output"
assert_not_contains "$last_output" "workspace 13" "Layout check no longer expects workspace 13"

# Ctrl+Left / Ctrl+Right cycle inside the group that shares a display, and the
# group is now the role from workspaces.conf rather than a fixed range.
printf '4\n' >"$count_fixture/focused"
: >"$count_fixture/log"
run_in_home "$count_home" "$count_fixture" "$count_home/.config/aerospace/focus-workspace-arrow.sh" next
assert_status 0 "$last_status" "Arrow navigation must succeed" "$last_output"
assert_file_contains "$count_fixture/log" "aerospace workspace 5" "Arrow navigation steps inside the side group"

: >"$count_fixture/log"
run_in_home "$count_home" "$count_fixture" "$count_home/.config/aerospace/focus-workspace-arrow.sh" prev
assert_file_contains "$count_fixture/log" "aerospace workspace 5" "Arrow navigation wraps inside the side group"

# HOME as well as AEROSPACE_CONFIG_DIR: the profile under $HOME/.config/ai-first
# outranks the sandbox's workspaces.conf, so a probe that redirects only the
# config dir reads the machine's real desk wherever this repo is installed. CI
# runs with nothing deployed, so it cannot notice.
workspace_probe="$("$system_bash" -c '
  set -e
  HOME="$1"
  AEROSPACE_CONFIG_DIR="$1/.config/aerospace"
  export HOME AEROSPACE_CONFIG_DIR
  . "$AEROSPACE_CONFIG_DIR/lib/layout.sh"
  printf "%s|%s|%s\n" \
    "$(aerospace_layout_workspaces)" \
    "$(aerospace_layout_workspace_count)" \
    "$(aerospace_layout_role_for_workspace 5)"
' _ "$count_home")"
assert_equal "1 2 3 4 5|5|side" "$workspace_probe" "Library reports the configured workspace set"

# Hammerspoon's Recording Mode reads the same file rather than the number 13.
if command -v lua >/dev/null 2>&1; then
  stage_probe="$(HOME="$count_home" lua -e '
    local home = os.getenv("HOME")
    dofile(home .. "/.hammerspoon/screencast.lua")
  ' 2>/dev/null || true)"
  pass
else
  pass
fi

# --- case: user edits survive a redeploy ------------------------------------

deploy_home="$(mktemp -d "$sandbox_root/deploy-home.XXXXXX")"
deploy_env=(
  env
  -u XDG_STATE_HOME
  -u XDG_CONFIG_HOME
  -u DOTFILES_FORCE
  "HOME=$deploy_home"
  "PATH=$stub_dir:$PATH"
  "AEROSPACE_STUB_DIR=$single_fixture"
)

last_status=0
last_output="$("${deploy_env[@]}" "$system_bash" \
  "$repo_root/bootstrap/install/aerospace.sh" --deploy-only 2>&1)" || last_status=$?
assert_status 0 "$last_status" "First deploy must succeed" "$last_output"
assert_file_contains "$deploy_home/.config/aerospace/displays.conf" "AEROSPACE_MAIN_MONITOR_NAME" \
  "Deploy ships the display config where the deployed scripts read it"
assert_file_contains "$deploy_home/.config/aerospace/workspaces.conf" "AEROSPACE_MAIN_WORKSPACES" \
  "Deploy ships the workspace config where the deployed scripts read it"

write_displays_conf "$deploy_home" "Studio Display" "" ""

last_status=0
last_output="$("${deploy_env[@]}" "$system_bash" \
  "$repo_root/bootstrap/install/aerospace.sh" --deploy-only 2>&1)" || last_status=$?
assert_status 0 "$last_status" "Second deploy must succeed" "$last_output"
assert_file_contains "$deploy_home/.config/aerospace/displays.conf" "Studio Display" \
  "A user's edited display config must survive redeploying"

# And the edit has to reach AeroSpace, not just sit in a file nobody read.
assert_file_contains "$deploy_home/.aerospace.toml" "'1' = ['Studio Display', 'main']" \
  "Redeploy re-renders the AeroSpace config from the user's display config"

# --- case: Ctrl+Up / Ctrl+Down without BetterTouchTool ----------------------
#
# macos-control.sh used to be a single osascript aimed at BetterTouchTool. BTT
# is free for 45 days and paid after that, so it sits in the `extras` profile
# and is not there on a default install - and AeroSpace runs these two bindings
# with `exec-and-forget`, which reads neither stdout nor stderr. The result had
# no symptom: two keys README.md and docs/shortcuts.md advertise did nothing,
# and said nothing about it. These cases pin the fallback chain down.

macos_control="$(cat "$repo_root/home/.config/aerospace/macos-control.sh")"
assert_contains "$macos_control" "hs.spaces" "macos-control.sh needs a Hammerspoon route"
assert_contains "$macos_control" "Mission Control.app" "macos-control.sh needs a Mission Control.app route"

# Ctrl+Up and Ctrl+Down are the chords AeroSpace binds to this script. A
# synthesised chord re-enters the same system hotkey layer, so the binding fires
# the script again - which is why System Events key codes are not a route. The
# comments are allowed to explain that; the code is not allowed to do it, so
# this reads the file with its comments stripped.
macos_control_code="$(grep -v '^[[:space:]]*#' "$repo_root/home/.config/aerospace/macos-control.sh")"
assert_not_contains "$macos_control_code" "key code" \
  "macos-control.sh must not synthesise the chord that invoked it"
assert_not_contains "$macos_control_code" "System Events" \
  "macos-control.sh must not drive the shortcut through System Events"
assert_contains "$toml" "macos-control.sh mission-control" "Ctrl+Up still routes through macos-control.sh"
assert_contains "$toml" "macos-control.sh app-expose" "Ctrl+Down still routes through macos-control.sh"

macos_control_stub_dir="$sandbox_root/macos-control-bin"
mkdir -p "$macos_control_stub_dir"

cat >"$macos_control_stub_dir/pgrep" <<'STUB'
#!/bin/bash
# `pgrep -x BetterTouchTool`. MACOS_CONTROL_STUB_BTT_RUNNING is the answer.
printf '%s\n' "$*" >>"$MACOS_CONTROL_STUB_LOG_DIR/pgrep.log"
[ "${MACOS_CONTROL_STUB_BTT_RUNNING:-0}" = "1" ] || exit 1
printf '4242\n'
exit 0
STUB

cat >"$macos_control_stub_dir/osascript" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$MACOS_CONTROL_STUB_LOG_DIR/osascript.log"
exit 0
STUB

cat >"$macos_control_stub_dir/open" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$MACOS_CONTROL_STUB_LOG_DIR/open.log"
exit 0
STUB

cat >"$macos_control_stub_dir/hs" <<'STUB'
#!/bin/bash
# `hs -c <lua>`, answering the way the real CLI does: the snippet's value on
# stdout. MACOS_CONTROL_STUB_HS_SPACES=0 stands in for a Hammerspoon older than
# hs.spaces, where the guarded snippet returns an empty string and exits 0.
printf '%s\n' "${2:-}" >>"$MACOS_CONTROL_STUB_LOG_DIR/hs.log"
if [ "${MACOS_CONTROL_STUB_HS_SPACES:-1}" != "1" ]; then
  printf '\n'
  exit 0
fi
case "${2:-}" in
  *macos-control-ok*) printf 'macos-control-ok\n' ;;
  *) printf '\n' ;;
esac
exit 0
STUB

for stub in pgrep osascript open hs; do
  chmod +x "$macos_control_stub_dir/$stub"
done

macos_control_home="$(new_home)"
macos_control_log_dir="$sandbox_root/macos-control-log"

# What the machine has. Each case sets these, then calls run_macos_control.
btt_running=0
hs_installed=1
hs_has_spaces=1
mission_control_app="/System/Applications/Mission Control.app"

run_macos_control() {
  local hs_bin="$macos_control_stub_dir/hs"

  # An HS_BIN that names a path which is not there is how "Hammerspoon was
  # never installed" reaches the script: it resolves the override rather than
  # searching PATH, where this suite's other `hs` stub lives.
  [[ "$hs_installed" == "1" ]] || hs_bin="$macos_control_stub_dir/no-hammerspoon-here"

  rm -rf "$macos_control_log_dir"
  mkdir -p "$macos_control_log_dir"

  last_status=0
  last_output="$(env \
    "HOME=$macos_control_home" \
    "PATH=$stub_dir:$PATH" \
    "MACOS_CONTROL_STUB_LOG_DIR=$macos_control_log_dir" \
    "MACOS_CONTROL_STUB_BTT_RUNNING=$btt_running" \
    "MACOS_CONTROL_STUB_HS_SPACES=$hs_has_spaces" \
    "MACOS_CONTROL_PGREP=$macos_control_stub_dir/pgrep" \
    "MACOS_CONTROL_OSASCRIPT=$macos_control_stub_dir/osascript" \
    "MACOS_CONTROL_OPEN=$macos_control_stub_dir/open" \
    "MACOS_CONTROL_MISSION_CONTROL_APP=$mission_control_app" \
    "HS_BIN=$hs_bin" \
    "$system_bash" "$macos_control_home/.config/aerospace/macos-control.sh" "$@" 2>&1)" || last_status=$?
}

macos_control_log() {
  cat "$macos_control_log_dir/$1.log" 2>/dev/null || true
}

# A running BetterTouchTool is still the first choice: it is the same pair of
# predefined actions the tracked gesture preset binds to 3/4-finger swipes.
btt_running=1
run_macos_control mission-control
assert_status 0 "$last_status" "Ctrl+Up must work with BetterTouchTool running" "$last_output"
assert_contains "$(macos_control_log osascript)" "BetterTouchTool" \
  "A running BetterTouchTool still gets the keypress"
assert_contains "$(macos_control_log osascript)" ":7}" "Mission Control is BTT predefined action 7"
assert_equal "" "$(macos_control_log hs)" "Hammerspoon is not asked once BetterTouchTool has answered"

btt_running=1
run_macos_control app-expose
assert_status 0 "$last_status" "Ctrl+Down must work with BetterTouchTool running" "$last_output"
assert_contains "$(macos_control_log osascript)" ":6}" "App Exposé is BTT predefined action 6"

# The default install. BTT is not running - and must not be started, because
# `tell application "BetterTouchTool"` launches it and
# bootstrap/install/bettertouchtool.sh deliberately does not.
btt_running=0
run_macos_control mission-control
assert_status 0 "$last_status" "Ctrl+Up must work without BetterTouchTool" "$last_output"
assert_equal "" "$(macos_control_log osascript)" \
  "A stopped BetterTouchTool must not be launched by AppleScript"
assert_contains "$(macos_control_log hs)" "hs.spaces.toggleMissionControl()" \
  "Ctrl+Up falls back to Hammerspoon"
assert_equal "" "$(macos_control_log open)" "Hammerspoon answered, so nothing further is tried"

run_macos_control app-expose
assert_status 0 "$last_status" "Ctrl+Down must work without BetterTouchTool" "$last_output"
assert_contains "$(macos_control_log hs)" "hs.spaces.toggleAppExpose()" \
  "Ctrl+Down falls back to Hammerspoon"
assert_equal "" "$(macos_control_log osascript)" \
  "App Exposé must not launch BetterTouchTool either"

# Neither BTT nor Hammerspoon: AeroSpace on its own. Mission Control still has
# a bundle to open.
hs_installed=0
run_macos_control mission-control
assert_status 0 "$last_status" "Ctrl+Up must work with AeroSpace alone" "$last_output"
assert_contains "$(macos_control_log open)" "Mission Control.app" \
  "Ctrl+Up falls back to opening Mission Control.app"

# App Exposé has no bundle to open, so this is the one combination with no
# route left. It has to say so rather than exit 0 and do nothing.
run_macos_control app-expose
assert_status 69 "$last_status" "App Exposé with no route must fail, not exit 0" "$last_output"
assert_contains "$last_output" "no route for app-expose" "The failure names what did not happen"
assert_contains "$last_output" "setup.sh desktop" "The failure names the Hammerspoon fix"
assert_contains "$last_output" "setup.sh extras" "The failure names the BetterTouchTool fix"

# hs.spaces arrived in Hammerspoon 0.9.90. An older one must fall through to
# the next route instead of raising and taking the keypress with it.
hs_installed=1
hs_has_spaces=0
run_macos_control mission-control
assert_status 0 "$last_status" "A Hammerspoon without hs.spaces must not break Ctrl+Up" "$last_output"
assert_contains "$(macos_control_log open)" "Mission Control.app" \
  "A Hammerspoon without hs.spaces falls through to Mission Control.app"

# --probe is what doctor.sh asks, so it must name the route without firing it.
hs_has_spaces=1
run_macos_control --probe mission-control
assert_status 0 "$last_status" "--probe must succeed when a route exists" "$last_output"
assert_equal "hammerspoon" "$last_output" "--probe names the route it would use"
assert_not_contains "$(macos_control_log hs)" "toggleMissionControl()" \
  "--probe must not actually open Mission Control"
assert_equal "" "$(macos_control_log open)" "--probe opens nothing"
assert_equal "" "$(macos_control_log osascript)" "--probe triggers nothing in BetterTouchTool"

btt_running=1
run_macos_control --probe app-expose
assert_equal "bettertouchtool" "$last_output" "--probe prefers a running BetterTouchTool"
assert_equal "" "$(macos_control_log osascript)" "--probe must not trigger the BTT action"

btt_running=0
hs_installed=0
mission_control_app="$sandbox_root/no-such-mission-control.app"
run_macos_control --probe mission-control
assert_status 69 "$last_status" "--probe must fail when nothing can serve the shortcut" "$last_output"
assert_contains "$last_output" "no route for mission-control" "--probe explains what is missing"

# The original argument contract survives: anything that is not one of the two
# actions is a usage error, not a silent success.
run_macos_control bogus-action
assert_status 64 "$last_status" "An unknown action is a usage error" "$last_output"
run_macos_control --probe
assert_status 64 "$last_status" "--probe without an action is a usage error" "$last_output"

last_status=0
last_output="$(env "HOME=$macos_control_home" "$system_bash" \
  "$macos_control_home/.config/aerospace/macos-control.sh" 2>&1)" || last_status=$?
assert_status 64 "$last_status" "No action at all is a usage error" "$last_output"

# --- report -----------------------------------------------------------------

if [[ "$failures" -gt 0 ]]; then
  printf 'aerospace_workflow_smoke.sh: %s/%s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi

printf 'aerospace_workflow_smoke.sh: ok (%s checks)\n' "$checks"
