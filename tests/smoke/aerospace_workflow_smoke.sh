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
run_in_home() {
  local home_dir="$1" fixture="$2"
  shift 2

  last_status=0
  last_output="$(env \
    -u XDG_STATE_HOME \
    -u XDG_CONFIG_HOME \
    -u AEROSPACE_MAIN_MONITOR_NAME \
    -u AEROSPACE_SIDE_MONITOR_NAME \
    -u AEROSPACE_STAGE_MONITOR_NAME \
    "HOME=$home_dir" \
    "PATH=$stub_dir:$PATH" \
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
start_seconds="$(date +%s)"
run_in_home "$single_home" "$single_fixture" "$single_home/.config/aerospace/startup-restore.sh"
elapsed=$(($(date +%s) - start_seconds))
assert_status 0 "$last_status" "Login restore must succeed with one display" "$last_output"
if [[ "$elapsed" -le 6 ]]; then
  pass
else
  fail "Login restore waited ${elapsed}s on a single-display Mac (was ~22s, budget 6s)" "$last_output"
fi
printf 'single-display startup-restore.sh: %ss wall clock (default settle delay)\n' "$elapsed"

# Without the deliberate settle delay, nothing else may block at all.
start_seconds="$(date +%s)"
last_status=0
last_output="$(env -u XDG_STATE_HOME "HOME=$single_home" "PATH=$stub_dir:$PATH" \
  "AEROSPACE_STUB_DIR=$single_fixture" "HS_STUB_SCREENS=$single_fixture/screens" \
  "AEROSPACE_BIN=$stub_dir/aerospace" "HS_BIN=$stub_dir/hs" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "SKETCHYBAR_TEST_LOG=$single_fixture/sketchybar.log" \
  AEROSPACE_STARTUP_RESTORE_DELAY=0 \
  "$system_bash" "$single_home/.config/aerospace/startup-restore.sh" 2>&1)" || last_status=$?
elapsed=$(($(date +%s) - start_seconds))
if [[ "$elapsed" -le 3 ]]; then
  pass
else
  fail "Login restore blocked ${elapsed}s with no settle delay on one display" "$last_output"
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

workspace_probe="$("$system_bash" -c '
  set -e
  AEROSPACE_CONFIG_DIR="$1/.config/aerospace"
  export AEROSPACE_CONFIG_DIR
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

# --- report -----------------------------------------------------------------

if [[ "$failures" -gt 0 ]]; then
  printf 'aerospace_workflow_smoke.sh: %s/%s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi

printf 'aerospace_workflow_smoke.sh: ok (%s checks)\n' "$checks"
