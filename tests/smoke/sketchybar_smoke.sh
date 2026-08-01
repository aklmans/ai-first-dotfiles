#!/usr/bin/env bash
set -euo pipefail

# Covers the SketchyBar layer: the theme single source of truth, the workspace
# list it shares with AeroSpace, and what happens when the programs it calls are
# not installed.
#
# Why this exists. SketchyBar's scripts call `aerospace` and `hs`, and used to
# call them at fixed Homebrew paths with no check that anything was there. A Mac
# with a tiling window manager and no status bar, or a status bar and no Lua
# runtime, are both reasonable machines to have; on them the display resolver
# returned an empty string, which is indistinguishable from "that monitor is not
# connected", so the bar bound its workspace items to whatever display it landed
# on and looked like it was working. Separately, the plugin that repaints the
# workspace chips carried the literal string "1 2 3 4 5 6 7 8 9 10 11 12 13"
# while the item file that creates them read the real list from AeroSpace, so
# the two disagreed for anyone who did not run thirteen workspaces.
#
# Everything that would touch the machine (aerospace, hs, sketchybar) is stubbed
# on PATH, HOME is a throwaway directory, and the scripts under test run on
# /bin/bash so bash 3.2 regressions cannot hide.
#
# Not covered here, and not coverable here: whether SketchyBar actually renders
# what these arguments describe. This asserts the arguments.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
system_bash="/bin/bash"

if [[ ! -x "$system_bash" ]]; then
  printf 'Missing %s; these scripts must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-smoke.XXXXXX")"
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
    fail "$label" "missing: $needle
in:
$haystack"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    pass
  else
    fail "$label" "unexpected: $needle
in:
$haystack"
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

# The last hard-coded workspace list. Both the item file and the plugin used to
# carry it; either one keeping it means they can disagree again.
hardcoded="$(grep -rn '1 2 3 4 5 6 7 8 9 10 11 12 13' "$repo_root/home/.config/sketchybar/" 2>/dev/null || true)"
assert_equal "" "$hardcoded" "SketchyBar must not hard-code a workspace list"

# The theme knobs have to be readable by something that is not bash: AeroSpace
# rewrites its top gap from Python and Hammerspoon reads config files with a
# line matcher. Command substitution or a reference to another variable would be
# invisible to both.
theme_conf="$repo_root/home/.config/sketchybar/theme.conf"
bad_lines="$(grep -vE '^[[:space:]]*(#|$)' "$theme_conf" | grep -vE '^[A-Z_]+="[^"$`]*"$' || true)"
assert_equal "" "$bad_lines" "theme.conf must be plain KEY=\"value\" lines"

# --- theme: one edit, every consumer -----------------------------------------

read_theme() {
  local config_dir="$1" name="$2"

  env -u SKETCHYBAR_WORKSPACES "SKETCHYBAR_THEME_CONFIG_DIR=$config_dir" \
    "$system_bash" "$config_dir/lib/theme.sh" get "$name" 2>/dev/null
}

theme_dir="$sandbox_root/theme-config"
mkdir -p "$theme_dir"
cp -R "$repo_root/home/.config/sketchybar/." "$theme_dir/"

assert_equal "SF Pro" "$(read_theme "$theme_dir" THEME_FONT)" "Shipped font family"
assert_equal "SF Pro:Bold:14.0" "$(read_theme "$theme_dir" THEME_FONT_ICON)" "Shipped icon font string"
assert_equal "SF Pro:Semibold:14.0" "$(read_theme "$theme_dir" THEME_FONT_BADGE)" "Shipped badge font string"

# The number AeroSpace's outer.top gap and Hammerspoon's Recording Mode both
# have to agree with. It is derived, so raising the bar cannot leave a strip of
# windows hidden underneath it.
assert_equal "95" "$(read_theme "$theme_dir" THEME_TOP_INSET)" "Shipped top inset matches the AeroSpace gap"
assert_file_contains "$repo_root/home/.aerospace.toml" "outer.top = 95" \
  "AeroSpace's top gap still matches the derived inset"

# One line changed, and the font moves everywhere it is used.
/usr/bin/sed -i '' 's/^SKETCHYBAR_FONT_FAMILY=.*/SKETCHYBAR_FONT_FAMILY="Helvetica Neue"/' "$theme_dir/theme.conf"
assert_equal "Helvetica Neue" "$(read_theme "$theme_dir" THEME_FONT)" "Font family follows theme.conf"
assert_equal "Helvetica Neue:Bold:14.0" "$(read_theme "$theme_dir" THEME_FONT_ICON)" \
  "Icon font follows theme.conf"
assert_equal "Helvetica Neue:Semibold:14.0" "$(read_theme "$theme_dir" THEME_FONT_BADGE)" \
  "Badge font follows theme.conf - this string used to be spelled out in the plugin"

# One line changed, and the reserved space follows the bar.
/usr/bin/sed -i '' 's/^SKETCHYBAR_BAR_HEIGHT=.*/SKETCHYBAR_BAR_HEIGHT="60"/' "$theme_dir/theme.conf"
assert_equal "60" "$(read_theme "$theme_dir" THEME_BAR_HEIGHT)" "Bar height follows theme.conf"
assert_equal "115" "$(read_theme "$theme_dir" THEME_TOP_INSET)" \
  "Top inset follows the bar height instead of being written down again"

# A palette role can be moved by name or pinned to a literal colour.
/usr/bin/sed -i '' 's/^SKETCHYBAR_ACCENT_CLOCK=.*/SKETCHYBAR_ACCENT_CLOCK="GREEN"/' "$theme_dir/theme.conf"
assert_equal "0xffa6da95" "$(read_theme "$theme_dir" THEME_ACCENT_CLOCK)" "Accent resolves a palette name"
/usr/bin/sed -i '' 's/^SKETCHYBAR_ACCENT_CLOCK=.*/SKETCHYBAR_ACCENT_CLOCK="0xff112233"/' "$theme_dir/theme.conf"
assert_equal "0xff112233" "$(read_theme "$theme_dir" THEME_ACCENT_CLOCK)" "Accent accepts a literal colour"

# Four item files reference $BORDER_WIDTH and nothing ever defined it.
assert_equal "2" "$(read_theme "$theme_dir" THEME_ITEM_BORDER_WIDTH)" "Item border width has a value at last"

# --- stubs ------------------------------------------------------------------

stub_dir="$sandbox_root/stub-bin"
mkdir -p "$stub_dir"

cat >"$stub_dir/aerospace" <<'STUB'
#!/bin/bash
# Reads its answers from $AEROSPACE_STUB_DIR.
fixture="${AEROSPACE_STUB_DIR:-}"
[ -n "$fixture" ] || exit 1

case "${1:-}" in
  list-monitors)
    cat "$fixture/monitors" 2>/dev/null || true
    ;;
  list-workspaces)
    for arg in "$@"; do
      if [ "$arg" = "--focused" ]; then
        cat "$fixture/focused" 2>/dev/null || printf '1\n'
        exit 0
      fi
    done
    cat "$fixture/all-workspaces" 2>/dev/null || true
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

for stub in aerospace hs sketchybar; do
  chmod +x "$stub_dir/$stub"
done

# --- sandbox home -----------------------------------------------------------

new_home() {
  local home_dir
  home_dir="$(mktemp -d "$sandbox_root/home.XXXXXX")"

  mkdir -p "$home_dir/.config"
  cp -R "$repo_root/home/.config/sketchybar" "$home_dir/.config/sketchybar"
  cp -R "$repo_root/home/.config/aerospace" "$home_dir/.config/aerospace"

  printf '%s\n' "$home_dir"
}

three_display_fixture() {
  local dir="$1"

  mkdir -p "$dir"
  {
    printf '1\tPHL 279C9\n'
    printf '2\tBuilt-in Retina Display\n'
    printf '3\t24V5C2\n'
  } >"$dir/monitors"
  printf '1\n' >"$dir/focused"
  printf '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n' >"$dir/all-workspaces"
  {
    printf '1\tWarp\n'
    printf '2\tGoLand\n'
  } >"$dir/windows"
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

probe_plugins="$sandbox_root/probe-plugins"
mkdir -p "$probe_plugins"
printf '#!/bin/bash\nexit 0\n' >"$probe_plugins/aerospace_spaces_refresh.sh"
chmod +x "$probe_plugins/aerospace_spaces_refresh.sh"

# Runs a bar script with the machine stubbed out. Extra `KEY=value` arguments
# are passed to env before the script path, which is how a case removes one of
# the binaries.
last_output=""
last_status=0
run_bar_script() {
  local home_dir="$1" fixture="$2"
  shift 2
  local -a extra_env
  extra_env=()

  while [[ "${1:-}" == *=* ]]; do
    extra_env+=("$1")
    shift
  done

  last_status=0
  last_output="$(env \
    -u XDG_STATE_HOME \
    -u XDG_CONFIG_HOME \
    -u SKETCHYBAR_WORKSPACES \
    -u AEROSPACE_MAIN_MONITOR_NAME \
    -u AEROSPACE_SIDE_MONITOR_NAME \
    -u AEROSPACE_STAGE_MONITOR_NAME \
    "HOME=$home_dir" \
    "PATH=$stub_dir:$PATH" \
    "AEROSPACE_STUB_DIR=$fixture" \
    "HS_STUB_SCREENS=$fixture/screens" \
    "SKETCHYBAR_STUB_DISPLAYS=$fixture/displays.json" \
    "SKETCHYBAR_TEST_LOG=$fixture/sketchybar.log" \
    "PLUGIN_DIR=$probe_plugins" \
    "CONFIG_DIR=$home_dir/.config/sketchybar" \
    ${extra_env[@]+"${extra_env[@]}"} \
    "$system_bash" "$@" 2>&1)" || last_status=$?
}

home_dir="$(new_home)"
fixture="$sandbox_root/fixture"
three_display_fixture "$fixture"

# --- case: the full install still behaves -----------------------------------

: >"$fixture/sketchybar.log"
run_bar_script "$home_dir" "$fixture" \
  "AEROSPACE_BIN=$stub_dir/aerospace" "HS_BIN=$stub_dir/hs" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "$home_dir/.config/sketchybar/items/spaces.sh"
assert_status 0 "$last_status" "Workspace items must be created with everything installed" "$last_output"
assert_file_contains "$fixture/sketchybar.log" "--add item space.13 left" \
  "The thirteenth workspace still gets a chip on the author's desk"
assert_file_contains "$fixture/sketchybar.log" "--add item space_creator left" \
  "The AeroSpace refresh item is added when AeroSpace is there"

: >"$fixture/sketchybar.log"
run_bar_script "$home_dir" "$fixture" \
  "AEROSPACE=$stub_dir/aerospace" "SKETCHYBAR=$stub_dir/sketchybar" \
  "$home_dir/.config/sketchybar/plugins/aerospace_spaces.sh"
assert_status 0 "$last_status" "Repainting chips must succeed with everything installed" "$last_output"
assert_file_contains "$fixture/sketchybar.log" "--set space.13" \
  "The repaint covers every workspace the items were created for"

# --- case: no aerospace CLI --------------------------------------------------

# Wanting a status bar without a tiling window manager, or having installed one
# and not the other yet, must not produce a crash or a screenful of noise.
: >"$fixture/sketchybar.log"
run_bar_script "$home_dir" "$fixture" \
  "AEROSPACE=/nonexistent/aerospace" "AEROSPACE_BIN=/nonexistent/aerospace" \
  "SKETCHYBAR=$stub_dir/sketchybar" \
  "$home_dir/.config/sketchybar/plugins/aerospace_spaces.sh"
assert_status 0 "$last_status" "Chip repaint must not fail without the aerospace CLI" "$last_output"
assert_contains "$last_output" "aerospace CLI not found" \
  "Missing aerospace is reported rather than swallowed"

run_bar_script "$home_dir" "$fixture" \
  "AEROSPACE=/nonexistent/aerospace" "AEROSPACE_BIN=/nonexistent/aerospace" \
  "SKETCHYBAR=$stub_dir/sketchybar" "NAME=aerospace_layout" "SENDER=routine" \
  "$home_dir/.config/sketchybar/plugins/aerospace_layout.sh"
assert_status 0 "$last_status" "Layout indicator must not fail without the aerospace CLI" "$last_output"

run_bar_script "$home_dir" "$fixture" \
  "AEROSPACE=/nonexistent/aerospace" "AEROSPACE_BIN=/nonexistent/aerospace" \
  "NAME=space.3" "SENDER=mouse.clicked" "BUTTON=left" "MODIFIER=" \
  "$home_dir/.config/sketchybar/plugins/space.sh"
assert_status 0 "$last_status" "Clicking a chip must not fail without the aerospace CLI" "$last_output"
assert_contains "$last_output" "aerospace CLI not found" \
  "A click that cannot switch workspaces says so"

# The bar still comes up: items are created from the AeroSpace config files,
# which are data and do not need the binary.
: >"$fixture/sketchybar.log"
run_bar_script "$home_dir" "$fixture" \
  "AEROSPACE_BIN=/nonexistent/aerospace" "HS_BIN=$stub_dir/hs" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "$home_dir/.config/sketchybar/items/spaces.sh"
assert_status 0 "$last_status" "Workspace items must still be created without the aerospace CLI" "$last_output"
assert_file_contains "$fixture/sketchybar.log" "--add item space.1 left" \
  "Workspace chips come from the config files, not from the binary"
assert_not_contains "$(cat "$fixture/sketchybar.log")" "--add item space_creator" \
  "The AeroSpace refresh item is not added when there is no AeroSpace to refresh from"

# --- case: no Hammerspoon ----------------------------------------------------

# The precise display mapping needs `hs`. Without it the resolver has to fall
# back to AeroSpace's monitor order and say so: an empty answer looks exactly
# like "that monitor is not connected", and the bar then binds its items to the
# wrong screen while appearing to work.
resolver_probe() {
  local hs_bin="$1"

  env \
    -u XDG_STATE_HOME \
    "HOME=$home_dir" \
    "PATH=/usr/bin:/bin" \
    "HS_BIN=$hs_bin" \
    "HS_STUB_SCREENS=$fixture/screens" \
    "AEROSPACE_BIN=$stub_dir/aerospace" \
    "AEROSPACE_STUB_DIR=$fixture" \
    "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
    "SKETCHYBAR_STUB_DISPLAYS=$fixture/displays.json" \
    "$system_bash" -c '
      set -euo pipefail
      . "$HOME/.config/sketchybar/lib/display-resolver.sh"
      printf "id=%s\n" "$(sketchybar_display_id_for_monitor "PHL 279C9" || printf "")"
    ' 2>&1
}

with_hs="$(resolver_probe "$stub_dir/hs")"
assert_contains "$with_hs" "id=2" "With Hammerspoon the monitor resolves by screen identity"
assert_not_contains "$with_hs" "not found" "With Hammerspoon there is nothing to warn about"

without_hs="$(resolver_probe "/nonexistent/hs")"
assert_contains "$without_hs" "Hammerspoon CLI (hs) not found" \
  "A missing Hammerspoon is reported, not swallowed"
assert_contains "$without_hs" "id=1" \
  "Without Hammerspoon the resolver falls back to the aerospace monitor order"

# Neither program: no answer, and the caller can tell.
without_either="$(env -u XDG_STATE_HOME "HOME=$home_dir" "PATH=/usr/bin:/bin" \
  "HS_BIN=/nonexistent/hs" "AEROSPACE_BIN=/nonexistent/aerospace" \
  "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "$system_bash" -c '
    set -euo pipefail
    . "$HOME/.config/sketchybar/lib/display-resolver.sh"
    printf "id=[%s]\n" "$(sketchybar_display_id_for_monitor "PHL 279C9" || printf "")"
  ' 2>&1)"
assert_contains "$without_either" "id=[]" "With neither program the resolver returns nothing"
assert_contains "$without_either" "Hammerspoon CLI (hs) not found" \
  "With neither program the reason is still printed"

# And the whole item file survives it: every workspace lands on a display that
# exists rather than on displays 2 and 3 of a laptop that has neither.
: >"$fixture/sketchybar.log"
run_bar_script "$home_dir" "$fixture" \
  "HS_BIN=/nonexistent/hs" "AEROSPACE_BIN=/nonexistent/aerospace" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "$home_dir/.config/sketchybar/items/spaces.sh"
assert_status 0 "$last_status" "Workspace items must be created with neither hs nor aerospace" "$last_output"
displays="$(grep -o -- '--set space\.[0-9]* display=[0-9]*' "$fixture/sketchybar.log" |
  sed 's/.*display=//' | LC_ALL=C sort -u | tr '\n' ' ')"
assert_equal "1 " "$displays" "Unresolvable displays collapse onto the one that always exists"

# --- case: five workspaces ---------------------------------------------------

# The plugin used to carry the number thirteen while the item file read the real
# list, so they disagreed for everyone who edited workspaces.conf.
five_home="$(new_home)"
cat >"$five_home/.config/aerospace/workspaces.conf" <<'EOF'
AEROSPACE_MAIN_WORKSPACES="1 2 3"
AEROSPACE_SIDE_WORKSPACES="4 5"
AEROSPACE_STAGE_WORKSPACES=""
EOF

before_hash="$(find "$five_home/.config/sketchybar" -type f -exec cksum {} \; | LC_ALL=C sort | cksum)"

: >"$fixture/sketchybar.log"
run_bar_script "$five_home" "$fixture" \
  "AEROSPACE=$stub_dir/aerospace" "SKETCHYBAR=$stub_dir/sketchybar" \
  "$five_home/.config/sketchybar/plugins/aerospace_spaces.sh"
assert_status 0 "$last_status" "Chip repaint must follow a five-workspace config" "$last_output"
repaint="$(cat "$fixture/sketchybar.log")"
assert_contains "$repaint" "--set space.5" "The repaint reaches the last workspace"
assert_not_contains "$repaint" "--set space.6" "The repaint stops where the workspaces stop"
assert_not_contains "$repaint" "--set space.13" "The repaint no longer knows the number thirteen"

: >"$fixture/sketchybar.log"
run_bar_script "$five_home" "$fixture" \
  "AEROSPACE_BIN=$stub_dir/aerospace" "HS_BIN=$stub_dir/hs" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "$five_home/.config/sketchybar/items/spaces.sh"
items="$(cat "$fixture/sketchybar.log")"
assert_contains "$items" "--add item space.5 left" "Chips are created for every configured workspace"
assert_not_contains "$items" "--add item space.6 left" "No chip is created for a workspace that does not exist"

after_hash="$(find "$five_home/.config/sketchybar" -type f -exec cksum {} \; | LC_ALL=C sort | cksum)"
assert_equal "$before_hash" "$after_hash" \
  "Changing the workspace count must not require editing a SketchyBar file"

# An explicit override wins, for a machine with a bar and no AeroSpace config.
: >"$fixture/sketchybar.log"
run_bar_script "$five_home" "$fixture" \
  "SKETCHYBAR_WORKSPACES=alpha beta" \
  "AEROSPACE=$stub_dir/aerospace" "SKETCHYBAR=$stub_dir/sketchybar" \
  "$five_home/.config/sketchybar/plugins/aerospace_spaces.sh"
assert_file_contains "$fixture/sketchybar.log" "--set space.alpha" \
  "SKETCHYBAR_WORKSPACES overrides the AeroSpace config"

# --- case: AeroSpace installed, SketchyBar not -------------------------------

# The reverse of the case above, and the one that used to end in `exit 1`:
# AeroSpace's login command sources this repo's display resolver out of the
# SketchyBar config directory. The library has to survive being sourced with no
# SketchyBar on the machine.
bare_home="$(mktemp -d "$sandbox_root/bare-home.XXXXXX")"
mkdir -p "$bare_home/.config"
cp -R "$repo_root/home/.config/sketchybar" "$bare_home/.config/sketchybar"

last_status=0
last_output="$(env -u XDG_STATE_HOME "HOME=$bare_home" "PATH=/usr/bin:/bin" \
  "SKETCHYBAR_BIN=/nonexistent/sketchybar" "HS_BIN=/nonexistent/hs" \
  "AEROSPACE_BIN=/nonexistent/aerospace" \
  "$system_bash" -c '
    set -euo pipefail
    . "$HOME/.config/sketchybar/lib/display-resolver.sh"
    printf "visible=%s\n" "$(sketchybar_visible_display_list_excluding 1)"
  ' 2>&1)" || last_status=$?
assert_status 0 "$last_status" "The display resolver must load without SketchyBar installed" "$last_output"
assert_contains "$last_output" "visible=all" \
  "Without SketchyBar the display list degrades to every display instead of failing"
assert_contains "$last_output" "cannot enumerate displays" \
  "Degrading to every display is announced rather than silent"

# --- case: theme reaches the arguments SketchyBar is given --------------------

: >"$fixture/sketchybar.log"
themed_home="$(new_home)"
/usr/bin/sed -i '' 's/^SKETCHYBAR_ACCENT_WORKSPACE_ACTIVE=.*/SKETCHYBAR_ACCENT_WORKSPACE_ACTIVE="0xff445566"/' \
  "$themed_home/.config/sketchybar/theme.conf"
run_bar_script "$themed_home" "$fixture" \
  "AEROSPACE=$stub_dir/aerospace" "SKETCHYBAR=$stub_dir/sketchybar" \
  "$themed_home/.config/sketchybar/plugins/aerospace_spaces.sh"
assert_file_contains "$fixture/sketchybar.log" "0xff445566" \
  "An accent edited in theme.conf reaches the repaint plugin"

: >"$fixture/sketchybar.log"
run_bar_script "$themed_home" "$fixture" \
  "AEROSPACE_BIN=$stub_dir/aerospace" "HS_BIN=$stub_dir/hs" "SKETCHYBAR_BIN=$stub_dir/sketchybar" \
  "$themed_home/.config/sketchybar/items/spaces.sh"
assert_file_contains "$fixture/sketchybar.log" "icon.highlight_color=0xff445566" \
  "The same accent reaches the item file that creates the chips"

# --- case: a user's theme survives a redeploy --------------------------------

deploy_home="$(mktemp -d "$sandbox_root/deploy-home.XXXXXX")"
deploy_env=(
  env
  -u XDG_STATE_HOME
  -u XDG_CONFIG_HOME
  -u DOTFILES_FORCE
  "HOME=$deploy_home"
  "PATH=$stub_dir:$PATH"
)

last_status=0
last_output="$("${deploy_env[@]}" "$system_bash" \
  "$repo_root/bootstrap/install/sketchybar.sh" --deploy-only 2>&1)" || last_status=$?
assert_status 0 "$last_status" "First deploy must succeed" "$last_output"
assert_file_contains "$deploy_home/.config/sketchybar/theme.conf" "SKETCHYBAR_FONT_FAMILY" \
  "Deploy ships the theme where the deployed scripts read it"

/usr/bin/sed -i '' 's/^SKETCHYBAR_BAR_HEIGHT=.*/SKETCHYBAR_BAR_HEIGHT="48"/' \
  "$deploy_home/.config/sketchybar/theme.conf"

last_status=0
last_output="$("${deploy_env[@]}" "$system_bash" \
  "$repo_root/bootstrap/install/sketchybar.sh" --deploy-only 2>&1)" || last_status=$?
assert_status 0 "$last_status" "Second deploy must succeed" "$last_output"
assert_file_contains "$deploy_home/.config/sketchybar/theme.conf" 'SKETCHYBAR_BAR_HEIGHT="48"' \
  "A user's edited theme must survive redeploying"
assert_equal "103" "$(read_theme "$deploy_home/.config/sketchybar" THEME_TOP_INSET)" \
  "The deployed theme still derives the inset from the user's bar height"

# --- AeroSpace without SketchyBar -------------------------------------------
# .aerospace.toml runs toggle-sketchybar-space.sh from after-startup-command, so
# an unguarded source of the SketchyBar resolver fails every login for anyone
# who wants tiling without a status bar.

solo_root="$(mktemp -d)"
mkdir -p "$solo_root/home/.config/aerospace"
cp "$repo_root"/home/.config/aerospace/*.sh "$solo_root/home/.config/aerospace/" 2>/dev/null || true
cp "$repo_root"/home/.config/aerospace/*.conf "$solo_root/home/.config/aerospace/" 2>/dev/null || true
cp -R "$repo_root/home/.config/aerospace/lib" "$solo_root/home/.config/aerospace/" 2>/dev/null || true
cp "$repo_root/home/.aerospace.toml" "$solo_root/home/.aerospace.toml"

# AeroSpace present, SketchyBar absent. AEROSPACE_BIN defaults to an absolute
# /opt/homebrew path, so without an explicit stub this test would silently use
# whatever the developer has installed and behave differently on a clean runner.
mkdir -p "$solo_root/bin"
cat >"$solo_root/bin/aerospace" <<'STUB'
#!/bin/sh
case "$1" in
  list-monitors) [ "$2" = "--count" ] && printf '1\n' || printf '1\tBuilt-in Retina Display\n' ;;
  list-workspaces) printf '1\n2\n3\n' ;;
esac
exit 0
STUB
chmod +x "$solo_root/bin/aerospace"

solo_status=0
solo_output="$(env -i "HOME=$solo_root/home" PATH=/usr/bin:/bin \
  "AEROSPACE_BIN=$solo_root/bin/aerospace" "AEROSPACE=$solo_root/bin/aerospace" \
  /bin/bash "$solo_root/home/.config/aerospace/toggle-sketchybar-space.sh" apply 2>&1)" || solo_status=$?

if [[ "$solo_status" -eq 0 ]]; then
  pass
else
  fail "toggle-sketchybar-space.sh must succeed with no SketchyBar installed" \
    "exit $solo_status
$solo_output"
fi
assert_not_contains "$solo_output" "display-resolver.sh: No such file" \
  "a missing SketchyBar resolver must degrade, not fail the source"
rm -rf "$solo_root"

# --- one glyph per chip ------------------------------------------------------
# items/volume.sh put the speaker in the icon and plugins/volume.sh put the same
# speaker in the label on every volume change, so the chip drew two of them and
# came out wider and rounder than everything beside it. Nothing here noticed:
# the bar was only ever checked for what it wrote, never for writing the same
# thing twice.

volume_root="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-volume.XXXXXX")"
mkdir -p "$volume_root/bin"
cat >"$volume_root/bin/sketchybar" <<'STUB'
#!/bin/bash
if [ "${1:-}" = "--query" ]; then
  printf '{"slider":{"width":0,"percentage":50}}\n'
  exit 0
fi
printf '%s\n' "$*" >>"${SKETCHYBAR_TEST_LOG:-/dev/null}"
exit 0
STUB
cat >"$volume_root/bin/jq" <<'STUB'
#!/bin/bash
# The plugin asks for slider.width and slider.percentage; both answers keep it
# on the path that does not animate, so the case does not wait on a sleep.
case "$*" in
  *width*) printf '0\n' ;;
  *) printf '50\n' ;;
esac
exit 0
STUB
chmod +x "$volume_root/bin/sketchybar" "$volume_root/bin/jq"

: >"$volume_root/log"
env -i "HOME=$volume_root" "PATH=$volume_root/bin:/usr/bin:/bin" \
  "CONFIG_DIR=$repo_root/home/.config/sketchybar" \
  "SKETCHYBAR_TEST_LOG=$volume_root/log" \
  "SENDER=volume_change" "INFO=50" "NAME=volume" \
  /bin/bash "$repo_root/home/.config/sketchybar/plugins/volume.sh" >/dev/null 2>&1 || true

volume_sets="$(grep -F 'volume_icon' "$volume_root/log" 2>/dev/null || true)"
assert_contains "$volume_sets" 'icon=' \
  "the volume plugin must put the speaker glyph in the icon"
assert_not_contains "$volume_sets" 'label=' \
  "the volume plugin must not put the same glyph in the label as well"

volume_item="$(cat "$repo_root/home/.config/sketchybar/items/volume.sh")"
assert_contains "$volume_item" 'label.drawing=off' \
  "the volume chip must not reserve a label slot it does not use"
# The bracket draws the pill around the slider and the icon together. A second
# background on the icon put two rounded rectangles and two borders in one place.
assert_contains "$volume_item" 'background.drawing=off' \
  "the volume icon must leave its pill to the bracket"
rm -rf "$volume_root"

# One bar, one shape: the workspace chips on the left and the pills on the right
# used 15 and 20, and at 26pt tall anything past 13 is already a full pill.
theme_conf="$(cat "$repo_root/home/.config/sketchybar/theme.conf")"
item_radius="$(printf '%s\n' "$theme_conf" | /usr/bin/awk -F'"' '/^SKETCHYBAR_ITEM_CORNER_RADIUS=/ { print $2 }')"
pill_radius="$(printf '%s\n' "$theme_conf" | /usr/bin/awk -F'"' '/^SKETCHYBAR_PILL_CORNER_RADIUS=/ { print $2 }')"
assert_equal "$item_radius" "$pill_radius" \
  "the right-hand pills must use the same corner radius as the workspace chips"

# --- theme presets -----------------------------------------------------------
# A preset overrides theme.conf for the keys it declares and leaves the rest of
# it alone, so switching looks cannot quietly discard an edit someone made.

preset_root="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-preset.XXXXXX")"
cp -R "$repo_root/home/.config/sketchybar" "$preset_root/sketchybar"

# Reads one resolved THEME_* variable out of a config directory. Each probe is
# its own shell because sketchybar_theme_load loads once and then returns early.
theme_value() {
  local dir="$1" name="$2"
  "$system_bash" -c '
    set -e
    . "$1/lib/theme.sh"
    sketchybar_theme_load "$1"
    eval "printf %s \"\${$2:-}\""
  ' _ "$dir" "$name" 2>/dev/null
}

select_preset_in() {
  local dir="$1" value="$2"
  /usr/bin/sed -e "s|^SKETCHYBAR_THEME_PRESET=.*|SKETCHYBAR_THEME_PRESET=\"$value\"|" \
    "$dir/theme.conf" >"$dir/theme.conf.next"
  mv "$dir/theme.conf.next" "$dir/theme.conf"
}

desk_height="$(theme_value "$preset_root/sketchybar" THEME_BAR_HEIGHT)"
desk_shadow="$(theme_value "$preset_root/sketchybar" THEME_BAR_SHADOW)"
assert_equal 'off' "$desk_shadow" \
  "the shipped theme must leave the bar shadow off"

select_preset_in "$preset_root/sketchybar" stream
stream_height="$(theme_value "$preset_root/sketchybar" THEME_BAR_HEIGHT)"
stream_notch="$(theme_value "$preset_root/sketchybar" THEME_BAR_NOTCH_WIDTH)"
desk_notch="$(theme_value "$repo_root/home/.config/sketchybar" THEME_BAR_NOTCH_WIDTH)"

if [[ "$stream_height" -gt "$desk_height" ]]; then
  pass
else
  fail "the stream preset must override what it declares" \
    "desk=$desk_height stream=$stream_height"
fi
assert_equal "$desk_notch" "$stream_notch" \
  "a key the preset does not declare must still come from theme.conf"
assert_equal 'on' "$(theme_value "$preset_root/sketchybar" THEME_BAR_SHADOW)" \
  "the stream preset must be able to turn depth on"

# The bar height and AeroSpace's outer.top gap are two written-down numbers that
# have to agree, and only one of them lives here. If a preset can change the
# derived inset - which it can, that is the point - then switching has to resync
# the other, which is what theme-control.sh calls toggle-sketchybar-space.sh for.
stream_inset="$(theme_value "$preset_root/sketchybar" THEME_TOP_INSET)"
desk_inset="$(theme_value "$repo_root/home/.config/sketchybar" THEME_TOP_INSET)"
if [[ "$stream_inset" -ne "$desk_inset" ]]; then
  pass
else
  fail "a preset that changes the bar height must change the reserved inset too" \
    "desk=$desk_inset stream=$stream_inset"
fi
# Whether the gap actually moves is aerospace_workflow_smoke.sh's case, because
# the rewriter lives over there. What belongs here is that the switch asks: the
# first version of this only checked that the word "apply" appeared in the file,
# which the script would still have passed with the call deleted.
assert_file_contains "$repo_root/home/.config/sketchybar/theme-control.sh" \
  'AEROSPACE_TOGGLE" apply' \
  "theme-control.sh must resync the window manager's gap after a switch"

# A preset name becomes a path. It arrives from a file people edit by hand.
#
# The target has to exist and has to change something, or the case passes with
# or without the whitelist: a traversal to a file that is not there is refused
# by the readability check either way, which is how the first version of this
# assertion managed to survive the whitelist being deleted.
printf 'SKETCHYBAR_BAR_HEIGHT="999"\n' >"$preset_root/reachable.conf"
select_preset_in "$preset_root/sketchybar" '../../reachable'
traversal_height="$(theme_value "$preset_root/sketchybar" THEME_BAR_HEIGHT)"
assert_equal "$desk_height" "$traversal_height" \
  "a preset name that is not a plain name must be refused"

# theme-control.sh owns one line of theme.conf and copies the rest through.
select_preset_in "$preset_root/sketchybar" ''
printf 'SKETCHYBAR_A_LOCAL_EDIT="kept"\n' >>"$preset_root/sketchybar/theme.conf"
"$system_bash" "$preset_root/sketchybar/theme-control.sh" stream >/dev/null 2>&1 || true
assert_file_contains "$preset_root/sketchybar/theme.conf" 'SKETCHYBAR_THEME_PRESET="stream"' \
  "theme-control.sh must select the preset"
assert_file_contains "$preset_root/sketchybar/theme.conf" 'SKETCHYBAR_A_LOCAL_EDIT="kept"' \
  "theme-control.sh must not discard the rest of theme.conf"
"$system_bash" "$preset_root/sketchybar/theme-control.sh" off >/dev/null 2>&1 || true
assert_file_contains "$preset_root/sketchybar/theme.conf" 'SKETCHYBAR_THEME_PRESET=""' \
  "theme-control.sh off must clear the selection"

control_status=0
"$system_bash" "$preset_root/sketchybar/theme-control.sh" no-such-preset >/dev/null 2>&1 ||
  control_status=$?
assert_equal 64 "$control_status" \
  "theme-control.sh must refuse a preset that does not exist"
rm -rf "$preset_root"

# --- report -----------------------------------------------------------------

if [[ "$failures" -gt 0 ]]; then
  printf 'sketchybar_smoke.sh: %s/%s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi

printf 'sketchybar_smoke.sh: ok (%s checks)\n' "$checks"
