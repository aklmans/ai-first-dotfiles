#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/smoke/lib/assert.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/quiet-profile.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
test_home="$test_dir/home"
mkdir -p "$test_home/.config/ai-first/modules/test-quiet" "$test_home/.config/aerospace"
cp -R "$repo_root/home/.config/ai-first/." "$test_home/.config/ai-first/"
cp -R "$repo_root/home/.config/aerospace/." "$test_home/.config/aerospace/"
# Synthetic user preferences, not a maintainer's private preset or app list.
cat >"$test_home/.config/ai-first/profile.conf" <<'EOF'
AI_FIRST_PRESET="test-quiet"
AI_FIRST_APP_ROUTING="1"
AI_FIRST_ROUTING_PACK="test-quiet"
AI_FIRST_FEATURE_WINDOW_AUTOMATION="0"
AI_FIRST_FEATURE_NOTIFICATIONS="0"
AI_FIRST_FEATURE_AI_HOTKEYS="0"
AI_FIRST_FEATURE_RECORDING="1"
AI_FIRST_BAR_CENTER_ITEMS=""
AI_FIRST_CLOCK_SECONDS="0"
AEROSPACE_MAIN_MONITOR_NAME="Primary Display"
AEROSPACE_SIDE_MONITOR_NAME="Secondary Display"
AEROSPACE_STAGE_MONITOR_NAME=""
AEROSPACE_MAIN_WORKSPACES="1 2 3"
AEROSPACE_SIDE_WORKSPACES="4 5 6"
AEROSPACE_STAGE_WORKSPACES=""
AEROSPACE_WORKSPACE_ROLE_MAP="development:1 stage:2"
EOF
cat >"$test_home/.config/aerospace/routing-packs/test-quiet.conf" <<'EOF'
id|org.example.Editor|development|prefer|tiling
id|org.example.Recorder|stage|prefer|floating
id|org.example.ContextTool|current|follow|floating
EOF
mkdir -p "$test_dir/bin"
cat >"$test_dir/bin/aerospace" <<'EOF'
#!/bin/bash
if [ "$1" = 'list-monitors' ]; then
  case "$QUIET_TEST_TOPOLOGY" in
    dual) printf '2\tSecondary Display\n1\tPrimary Display\n' ;;
    triple) printf '3\tBuilt-in Display\n2\tSecondary Display\n1\tPrimary Display\n' ;;
    portable) printf '9\tPortable Display\n' ;;
    laptop) printf '3\tBuilt-in Display\n' ;;
  esac
else
  printf 'Unexpected real-world action: %s\n' "$*" >&2
  exit 1
fi
EOF
chmod +x "$test_dir/bin/aerospace"
run_test() {
  env -u AI_FIRST_PROFILE_LOADED -u AEROSPACE_LAYOUT_CONFIG_LOADED \
    HOME="$test_home" AI_FIRST_CONFIG_DIR="$test_home/.config/ai-first" \
    AI_FIRST_PROFILE_PATH="$test_home/.config/ai-first/profile.conf" \
    AI_FIRST_PROFILE_LIB="$test_home/.config/ai-first/lib/profile.sh" \
    AEROSPACE_CONFIG_DIR="$test_home/.config/aerospace" \
    AEROSPACE_BIN="$test_dir/bin/aerospace" PATH="$test_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" "$@"
}

for topology in dual triple portable laptop; do
  resolved="$(QUIET_TEST_TOPOLOGY="$topology" run_test /bin/bash -c '
    source "$AEROSPACE_CONFIG_DIR/lib/layout.sh"
    aerospace_layout_resolve
    printf "%s|%s|%s|%s\n" "$(aerospace_layout_workspaces)" \
      "$AEROSPACE_RESOLVED_MAIN_NAME" "$AEROSPACE_RESOLVED_SIDE_NAME" \
      "$(aerospace_layout_role_for_workspace 2)"
  ')"
  case "$topology" in
    dual|triple) expected='1 2 3 4 5 6|Primary Display|Secondary Display|main' ;;
    portable) expected='1 2 3 4 5 6|Portable Display|Portable Display|main' ;;
    laptop) expected='1 2 3 4 5 6|Built-in Display|Built-in Display|main' ;;
  esac
  assert_equal "$expected" "$resolved" "$topology resolves every desk group without changing task numbers"
done
assert_equal '2' "$(run_test /bin/bash "$test_home/.config/aerospace/recording-target.sh")" 'recording uses the main-screen role, not old workspace 13'

routes="$(run_test /bin/bash -c '
  source "$AEROSPACE_CONFIG_DIR/app-defaults.sh"
  for app in org.example.Editor org.example.Recorder org.example.ContextTool; do
    printf "%s=%s\n" "$app" "$(aerospace_route_for_window "$app" "")"
  done
  if aerospace_route_for_window org.example.Unknown ""; then exit 1; fi
')"
assert_contains "$routes" 'org.example.Editor=development|prefer|tiling|1' 'app placement follows a custom semantic role'
assert_contains "$routes" 'org.example.Recorder=stage|prefer|floating|2' 'recorder and hotkey share the recording task role'
assert_contains "$routes" 'org.example.ContextTool=current|follow|floating|' 'context tools need no reserved workspace'

# Render a non-live path: render-app-rules deliberately does not reload any app.
cp "$repo_root/home/.aerospace.toml" "$test_dir/preview.toml"
run_test /bin/bash "$test_home/.config/aerospace/render-layout.sh" "$test_dir/preview.toml" >/dev/null
assert_file_contains "$test_dir/preview.toml" "ctrl-2 = 'workspace 2'" 'recording shortcut retains its actual workspace number'
assert_file_contains "$test_dir/preview.toml" "'2' = ['Primary Display', 'main']" 'recording pins to the selected display with a single-screen fallback'
assert_file_lacks "$test_dir/preview.toml" "workspace 13" 'no old workspace shortcut or app target survives'
render_hash="$(cksum <"$test_dir/preview.toml")"
run_test /bin/bash "$test_home/.config/aerospace/render-layout.sh" "$test_dir/preview.toml" >/dev/null
assert_equal "$render_hash" "$(cksum <"$test_dir/preview.toml")" 'custom profile rendering is idempotent'

prefs="$(run_test /bin/bash -c '
  source "$AI_FIRST_PROFILE_LIB"
  printf "%s|%s|%s|%s|%s|%s" "$AI_FIRST_FEATURE_WINDOW_AUTOMATION" \
    "$AI_FIRST_FEATURE_NOTIFICATIONS" "$AI_FIRST_FEATURE_AI_HOTKEYS" \
    "$AI_FIRST_FEATURE_RECORDING" "$AI_FIRST_BAR_CENTER_ITEMS" "$AI_FIRST_CLOCK_SECONDS"
')"
assert_equal '0|0|0|1||0' "$prefs" 'a profile can opt out of background rearranging, notifications, music and ticking seconds'

overrides="$(AI_FIRST_FEATURE_WINDOW_AUTOMATION=1 AI_FIRST_CLOCK_SECONDS=1 run_test /bin/bash -c '
  source "$AI_FIRST_PROFILE_LIB"
  printf "%s|%s" "$AI_FIRST_FEATURE_WINDOW_AUTOMATION" "$AI_FIRST_CLOCK_SECONDS"
')"
assert_equal '1|1' "$overrides" 'explicit environment preferences still outrank the preset'

# Real startup script, fake IPC and no actual sleeping or window changes.
cat >"$test_dir/bin/sketchybar" <<'EOF'
#!/bin/bash
printf 'bar %s\n' "$*" >>"$QUIET_TEST_EVENTS"
EOF
cat >"$test_dir/bin/reset" <<'EOF'
#!/bin/bash
printf 'reset\n' >>"$QUIET_TEST_EVENTS"
EOF
cat >"$test_dir/bin/spaces" <<'EOF'
#!/bin/bash
printf 'spaces\n' >>"$QUIET_TEST_EVENTS"
EOF
cat >"$test_dir/bin/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$test_dir/bin/sketchybar" "$test_dir/bin/reset" "$test_dir/bin/spaces" "$test_dir/bin/sleep"
export QUIET_TEST_EVENTS="$test_dir/events"
run_startup() {
  QUIET_TEST_TOPOLOGY=dual SKETCHYBAR_BIN="$test_dir/bin/sketchybar" \
    HS_BIN="$test_dir/not-installed" AEROSPACE_RESET_SCRIPT="$test_dir/bin/reset" \
    AEROSPACE_SPACES_PLUGIN="$test_dir/bin/spaces" \
    run_test /bin/bash "$test_home/.config/aerospace/startup-restore.sh"
}
run_startup
assert_file_contains "$QUIET_TEST_EVENTS" 'bar --reload' 'quiet startup still refreshes the bar'
assert_file_contains "$QUIET_TEST_EVENTS" 'spaces' 'quiet startup still refreshes workspace chips'
assert_file_lacks "$QUIET_TEST_EVENTS" 'reset' 'quiet startup never resets app positions'
AI_FIRST_FEATURE_WINDOW_AUTOMATION=1 run_startup
assert_file_contains "$QUIET_TEST_EVENTS" 'reset' 'legacy startup reset remains available by opt-in'

# Clock refresh must read its own profile, not depend on sketchybarrc exports.
: >"$QUIET_TEST_EVENTS"
NAME=clock run_test /bin/bash "$repo_root/home/.config/sketchybar/plugins/clock.sh"
assert_output_matches "$(<"$QUIET_TEST_EVENTS")" '^bar --set clock label=[0-9]{2}:[0-9]{2}$' 'quiet clock shows minutes without inherited settings'
AI_FIRST_CLOCK_SECONDS=1 NAME=clock run_test /bin/bash "$repo_root/home/.config/sketchybar/plugins/clock.sh"
assert_output_matches "$(<"$QUIET_TEST_EVENTS")" '^bar --set clock label=[0-9]{2}:[0-9]{2}:[0-9]{2}$' 'seconds remain an explicit option'
run_test /bin/bash -c 'source "$AI_FIRST_PROFILE_LIB"; source "$1"' _ "$repo_root/home/.config/sketchybar/items/clock.sh"
assert_file_contains "$QUIET_TEST_EVENTS" 'update_freq=60' 'quiet clock does not poll every second'

if command -v lua >/dev/null 2>&1; then
  lua_bin="$(command -v lua)"
  run_test "$lua_bin" "$repo_root/tests/lua/quiet_profile_runtime.lua" "$repo_root"
  pass
else
  printf 'SKIP: Lua runtime checks (lua not installed).\n'
fi
smoke_summary quiet_profile_smoke.sh
