#!/usr/bin/env bash
set -euo pipefail

# Pins the config-file security model: which of the files a user is invited to
# edit are read as data, and which are executed on purpose.
#
# What went wrong. The project's headline claim is that preferences are data,
# not patches, and profile.conf earns it - it is parsed, and a `$(...)` in it is
# punctuation. Three of the other files the README lists in the same table did
# not:
#
#   1. displays.conf and workspaces.conf were `source`d by lib/layout.sh, so a
#      monitor name written as "$(...)" ran as a command - at login, and again
#      every time SketchyBar asked for the workspace list.
#   2. lib/theme.sh resolved a palette role by building `${<whatever
#      theme.conf said>:-}` and handing it back to the shell. That is not a
#      colour-table lookup, it is a general expansion over the whole
#      environment: a role written as `x:-$(...)}` closed the brace and ran the
#      command substitution, twelve times per bar event.
#   3. The same shape sat behind `theme.sh get <name>`, driven by argv.
#
# All three are shaped like format bugs and none of them are visible to a test
# that only asserts the happy path, so they get a suite of their own. The
# assertions below are in two halves: the shipped files must stay inside the
# documented grammar, and a hostile value must be handled literally rather than
# run.
#
# What is deliberately NOT asserted here: colors.sh is a shell script and stays
# one. Its values are unquoted, nine of them reference other entries, one is a
# two-level chain, and thirty-odd commented-out palettes are there to be
# uncommented. Parsing that would break it. Its header says so out loud instead.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/assert.sh
. "$repo_root/tests/smoke/lib/assert.sh"

# The scripts under test run on the macOS system bash, so a bash 3.2 regression
# - ${!name} and printf -v both being 3.x features - cannot hide behind a
# newer bash on PATH.
system_bash="/bin/bash"
if [ ! -x "$system_bash" ]; then
  printf 'Missing %s; these scripts must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/config-injection-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

# Every probe a payload could touch lands here, inside the sandbox. A payload
# that writes to a fixed path outside it would make this suite pass or fail
# based on whatever the last run left behind.
mkdir -p "$sandbox_root/home"
probe="$sandbox_root/PWNED"
no_profile="$sandbox_root/no-such-profile.sh"

# --- the grammar, spelled once ----------------------------------------------

# Wider than profile.conf's on purpose. Hammerspoon's screencast.lua already
# matches `^%s*KEY%s*=%s*"..."` and the single-quoted form, and
# sketchybar/lib/workspaces.sh already strips either quote, so a stricter
# parser would reject files that ship today.
conf_keys='AEROSPACE_MAIN_MONITOR_NAME|AEROSPACE_SIDE_MONITOR_NAME|AEROSPACE_STAGE_MONITOR_NAME|AEROSPACE_MAIN_WORKSPACES|AEROSPACE_SIDE_WORKSPACES|AEROSPACE_STAGE_WORKSPACES|AEROSPACE_WORKSPACE_ROLE_MAP'
conf_value='("[^"]*"|'"'"'[^'"'"']*'"'"'|[A-Za-z0-9_.:/+-]*)'
conf_assignment="^[[:space:]]*($conf_keys)[[:space:]]*=[[:space:]]*$conf_value[[:space:]]*(#.*)?\$"
conf_blank='^[[:space:]]*(#.*)?$'

assert_conf_is_data() {
  local file="$1" label="$2"
  local offending

  offending="$(/usr/bin/grep -vE "$conf_blank" "$file" | /usr/bin/grep -vE "$conf_assignment" || true)"
  assert_equal "" "$offending" "$label"
}

# --- shipped files stay inside the grammar ----------------------------------

# theme.conf has had this assertion since it was introduced
# (sketchybar_smoke.sh). These two never did, which is how they stayed
# executable-by-accident for as long as they did.
assert_conf_is_data "$repo_root/home/.config/aerospace/displays.conf" \
  'displays.conf must be plain KEY=value lines'
assert_conf_is_data "$repo_root/home/.config/aerospace/workspaces.conf" \
  'workspaces.conf must be plain KEY=value lines'

# The two indirections that used to sit in theme.sh. Neither is replaceable by
# a narrower one - they were both general expansions - so the pin is that the
# file re-parses nothing at all.
theme_lib="$repo_root/home/.config/sketchybar/lib/theme.sh"
eval_uses="$(/usr/bin/grep -c '^[^#]*[^A-Za-z_]eval[^A-Za-z_]' "$theme_lib" || true)"
assert_equal "0" "$eval_uses" "theme.sh must not hand config values back to the shell to run"

# --- helpers ----------------------------------------------------------------

# A throwaway copy of the AeroSpace config. HOME points inside the sandbox and
# the profile library is deliberately absent, so the layering under test is the
# defaults plus the two conf files and nothing off this machine.
new_aerospace_dir() {
  local dir
  dir="$(mktemp -d "$sandbox_root/aerospace.XXXXXX")"
  cp -R "$repo_root/home/.config/aerospace/." "$dir/"
  printf '%s\n' "$dir"
}

# Sets layout_out and layout_stderr rather than printing, because a helper
# called as `$(layout_load ...)` runs in a subshell and every global it assigns
# - the captured stderr in particular - is discarded on the way out. An
# assertion against a variable that can only ever be empty passes forever.
layout_out=""
layout_stderr=""
layout_load() {
  local conf_dir="$1"
  local out_file="$sandbox_root/layout.out"
  local err_file="$sandbox_root/layout.err"

  : >"$out_file"
  : >"$err_file"
  env -u AEROSPACE_MAIN_MONITOR_NAME -u AEROSPACE_SIDE_MONITOR_NAME \
    -u AEROSPACE_STAGE_MONITOR_NAME -u AEROSPACE_MAIN_WORKSPACES \
    -u AEROSPACE_SIDE_WORKSPACES -u AEROSPACE_STAGE_WORKSPACES \
    -u AEROSPACE_WORKSPACE_ROLE_MAP \
    "HOME=$sandbox_root/home" "AEROSPACE_CONFIG_DIR=$conf_dir" \
    "AI_FIRST_PROFILE_LIB=$no_profile" \
    "$system_bash" -c '
      set -euo pipefail
      . "$AEROSPACE_CONFIG_DIR/lib/layout.sh"
      aerospace_layout_load_config
      printf "main=%s\n" "$AEROSPACE_MAIN_MONITOR_NAME"
      printf "side=%s\n" "$AEROSPACE_SIDE_MONITOR_NAME"
      printf "stage=%s\n" "$AEROSPACE_STAGE_MONITOR_NAME"
      printf "mainws=%s\n" "$AEROSPACE_MAIN_WORKSPACES"
      printf "sidews=%s\n" "$AEROSPACE_SIDE_WORKSPACES"
      printf "stagews=%s\n" "$AEROSPACE_STAGE_WORKSPACES"
      printf "roles=%s\n" "$AEROSPACE_WORKSPACE_ROLE_MAP"
    ' >"$out_file" 2>"$err_file" || true
  layout_out="$(cat "$out_file")"
  layout_stderr="$(cat "$err_file")"
}

# field <output> <name>
field() {
  printf '%s\n' "$1" | /usr/bin/sed -n "s/^$2=//p"
}

# Same shape, same reason: theme_value and theme_stderr are read after the
# call, never through a command substitution around it.
theme_value=""
theme_stderr=""
read_theme() {
  local config_dir="$1" name="$2"
  local out_file="$sandbox_root/theme.out"
  local err_file="$sandbox_root/theme.err"

  : >"$out_file"
  : >"$err_file"
  env -u SKETCHYBAR_WORKSPACES "SKETCHYBAR_THEME_CONFIG_DIR=$config_dir" \
    "$system_bash" "$config_dir/lib/theme.sh" get "$name" >"$out_file" 2>"$err_file" || true
  theme_value="$(cat "$out_file")"
  theme_stderr="$(cat "$err_file")"
}

set_accent() {
  /usr/bin/sed -i '' "s|^SKETCHYBAR_ACCENT_CLOCK=.*|SKETCHYBAR_ACCENT_CLOCK=$1|" "$2/theme.conf"
}

# --- displays.conf: a value is a value, not a command ------------------------

rm -f "$probe"
inject_dir="$(new_aerospace_dir)"
printf 'AEROSPACE_MAIN_MONITOR_NAME="$(touch %s)Studio"\n' "$probe" \
  >"$inject_dir/displays.conf"


layout_load "$inject_dir"
assert_path_absent "$probe" "displays.conf must not execute a command substitution in a value"
assert_equal '$(touch '"$probe"')Studio' "$(field "$layout_out" main)" \
  "The payload is the monitor name, handled literally"
assert_equal "1 2 3 4 5 6" "$(field "$layout_out" mainws)" \
  "A hostile displays.conf must not disturb the rest of the layout"
assert_not_contains "$layout_stderr" "executed rather than read as data" \
  "A quoted value is data, so it must not trip the compatibility fallback"

# --- displays.conf / workspaces.conf: the whole documented grammar -----------

wide_dir="$(new_aerospace_dir)"
{
  printf '  AEROSPACE_MAIN_MONITOR_NAME = "PHL 279C9"\n'
  printf "AEROSPACE_SIDE_MONITOR_NAME='24V5C2'   # the panel on the right\n"
  printf '\tAEROSPACE_STAGE_MONITOR_NAME=Built-in\n'
} >"$wide_dir/displays.conf"
{
  printf '# five workspaces, written every way the readers accept\n'
  printf 'AEROSPACE_MAIN_WORKSPACES="1 2 3"\n'
  printf "AEROSPACE_SIDE_WORKSPACES = '4 5'\n"
  printf 'AEROSPACE_STAGE_WORKSPACES=\n'
  printf 'AEROSPACE_WORKSPACE_ROLE_MAP="focus:2 notes:4"\n'
  printf 'SOME_OTHER_KEY="not one of the seven"\n'
} >"$wide_dir/workspaces.conf"

layout_load "$wide_dir"
assert_equal "PHL 279C9" "$(field "$layout_out" main)" "Leading indent and spaces around = are accepted"
assert_equal "24V5C2" "$(field "$layout_out" side)" "Single quotes and a trailing comment are accepted"
assert_equal "Built-in" "$(field "$layout_out" stage)" "A bare value is accepted"
assert_equal "1 2 3" "$(field "$layout_out" mainws)" "Double-quoted list"
assert_equal "4 5" "$(field "$layout_out" sidews)" "Single-quoted list with spaces around ="
assert_equal "" "$(field "$layout_out" stagews)" "An empty value empties the role"
assert_equal "focus:2 notes:4" "$(field "$layout_out" roles)" "The role map is read from the file"
assert_not_contains "$layout_stderr" "executed rather than read as data" \
  "Everything in the documented grammar parses without the fallback"

# A key outside the seven is parsed and ignored. Falling back to executing the
# file on an unknown key would hand the execution path back to anyone who can
# add one line, which is the thing this change closes.
assert_not_contains "$layout_stderr" "SOME_OTHER_KEY" "An unknown key is ignored, not executed"

# --- the shipped files need no fallback --------------------------------------

shipped_dir="$(new_aerospace_dir)"
layout_load "$shipped_dir"
assert_equal "" "$layout_stderr" "The shipped config files parse silently"
assert_equal "1 2 3 4 5 6" "$(field "$layout_out" mainws)" "Shipped main workspaces"
assert_equal "7 8 9 10 11 12" "$(field "$layout_out" sidews)" "Shipped side workspaces"
assert_equal "13" "$(field "$layout_out" stagews)" "Shipped stage workspace"

# --- workspaces.conf that is genuinely shell: fall back, and say so ----------

# Someone has been running a config like this since before the file was data.
# Breaking it on upgrade would be worse than executing it, so it is executed -
# once, loudly, with the file named.
legacy_dir="$(new_aerospace_dir)"
cat >"$legacy_dir/workspaces.conf" <<'LEGACY'
list=""
for n in 1 2 3; do
  list="$list $n"
done
AEROSPACE_MAIN_WORKSPACES="$list"
export AEROSPACE_SIDE_WORKSPACES="7 8"
AEROSPACE_STAGE_WORKSPACES=""
LEGACY

layout_load "$legacy_dir"
assert_contains "$layout_stderr" "executed rather than read as data" \
  "A config file the parser cannot represent falls back to being sourced"
assert_contains "$layout_stderr" "$legacy_dir/workspaces.conf" \
  "The warning names the file, so the user knows which one to fix"
assert_equal "1 2 3" "$(field "$layout_out" mainws)" "The fallback still produces the values it always did"
assert_equal "7 8" "$(field "$layout_out" sidews)" "An exported value survives the fallback"
assert_output_matches "$layout_stderr" '^aerospace: ' "The warning is prefixed and goes to stderr"

# One warning, not one per reader: layout.sh is sourced by several scripts in a
# single login.
warning_count="$(printf '%s\n' "$layout_stderr" | /usr/bin/grep -c 'executed rather than read as data' || true)"
assert_equal "1" "$warning_count" "The fallback warns once per file"

# --- theme.conf: a role name is looked up, not run ---------------------------

theme_dir="$sandbox_root/sketchybar"
mkdir -p "$theme_dir"
cp -R "$repo_root/home/.config/sketchybar/." "$theme_dir/"

magenta="0xffc6a0f6"
green="0xffa6da95"

read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "$magenta" "$theme_value" \
  "Shipped clock accent resolves the MAGENTA palette entry"

# The payload from the report: `x:-$(...)}` used to close the brace the resolver
# built and run the command substitution.
rm -f "$probe"
set_accent "'x:-\$(touch $probe)}'" "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_path_absent "$probe" "theme.conf must not execute a command substitution in a role"
assert_equal "$magenta" "$theme_value" "A role that is not a palette name falls back to the shipped colour"
assert_equal "" "$theme_stderr" "and does so silently"

# Theming as a whole still loads with that value in the file - the bar must not
# lose its fonts because one role was nonsense.
read_theme "$theme_dir" THEME_FONT
assert_equal "SF Pro" "$theme_value" "Theming still loads"
read_theme "$theme_dir" THEME_TOP_INSET
assert_equal "95" "$theme_value" "Derived top inset still resolves"

# --- theme.conf is read, not run ---------------------------------------------
#
# The case above only ever proved the *resolver* was safe. Closing the eval left
# theme.conf itself still being sourced, so a plain double-quoted value ran its
# command substitution at source time - before any resolver saw it - and no
# assertion here noticed, because every check was about colour resolution.
#
# This is the file the README tells people to edit for fonts and geometry, and
# it is read by the bar's config plus six item and plugin scripts, so it runs on
# every repaint.

cp -R "$repo_root/home/.config/sketchybar/." "$theme_dir/"
rm -f "$probe"
printf 'SKETCHYBAR_FONT_FAMILY="$(touch %s)Evil"\n' "$probe" >>"$theme_dir/theme.conf"

read_theme "$theme_dir" THEME_FONT
assert_path_absent "$probe" "theme.conf must not execute a command substitution in any value"
assert_equal "\$(touch $probe)Evil" "$theme_value" \
  "the substitution is kept as literal text, which is what makes it harmless"

# A file holding real shell still works, because someone has been running one.
cp -R "$repo_root/home/.config/sketchybar/." "$theme_dir/"
printf 'for _i in 1; do SKETCHYBAR_BAR_HEIGHT="99"; done\n' >>"$theme_dir/theme.conf"
read_theme "$theme_dir" THEME_BAR_HEIGHT
assert_equal "99" "$theme_value" "a theme.conf that is genuinely shell still applies"
assert_output_matches "$theme_stderr" 'holds shell beyond' \
  "and says once that it is being executed rather than read"

cp -R "$repo_root/home/.config/sketchybar/." "$theme_dir/"

# --- theme.sh: the four behaviours the rewrite had to preserve ---------------

# 1. An empty value is not an empty colour: it collapses to the built-in role
#    name, because the call site uses :- and not -.
set_accent '""' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "$magenta" "$theme_value" \
  "An empty role collapses to the built-in name, not to an empty colour"

# 2. A 0x value passes through verbatim. There is no hex validation and adding
#    one here would be a second change hiding inside this one.
set_accent '"0xzz"' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "0xzz" "$theme_value" \
  "A 0x value passes through unvalidated"
set_accent '"0xff112233"' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "0xff112233" "$theme_value" \
  "A literal colour is used as written"

# 3. A misspelt palette name degrades to the shipped colour, silently. Turning
#    a typo into an error would take the bar down over a config comment.
set_accent '"MEGENTA"' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "$magenta" "$theme_value" \
  "A misspelt palette name degrades to the shipped colour"
assert_equal "" "$theme_stderr" "and prints nothing"

# 4. Case-sensitive, and no trimming. GREEN is a real entry, so both of these
#    would resolve to green if either rule had quietly relaxed.
set_accent '"green"' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "$magenta" "$theme_value" \
  "Palette lookup stays case-sensitive"
set_accent '" GREEN"' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "$magenta" "$theme_value" \
  "Palette lookup does not trim"
set_accent '"GREEN"' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "$green" "$theme_value" \
  "and the name itself still resolves"

# Indirection reaches any variable in scope, including the names colors.sh
# derives from other names. POPUP_BACKGROUND_COLOR is $BAR_COLOR is $BG0.
set_accent '"POPUP_BACKGROUND_COLOR"' "$theme_dir"
read_theme "$theme_dir" THEME_ACCENT_CLOCK
assert_equal "0xff1e1e2e" "$theme_value" \
  "A two-level colors.sh chain still resolves"

# --- theme.sh get: argv is a name to look up, not a program ------------------

rm -f "$probe"
get_out="$(env "SKETCHYBAR_THEME_CONFIG_DIR=$theme_dir" "$system_bash" \
  "$theme_dir/lib/theme.sh" get "x};touch $probe;#" 2>/dev/null || true)"
assert_path_absent "$probe" "theme.sh get must not run what argv asks it to"
assert_equal "" "$get_out" "A name that is not a variable name resolves to nothing"

assert_equal "95" "$(env "SKETCHYBAR_THEME_CONFIG_DIR=$theme_dir" "$system_bash" \
  "$theme_dir/lib/theme.sh" get THEME_TOP_INSET)" \
  "and the documented use keeps working"

# --- sketchybar reads workspaces.conf the same way layout.sh writes it -------

# This is the partial-install path: SketchyBar with the config files but no
# AeroSpace library. Three programs read workspaces.conf, and a line one accepts
# and another skips is a chip for a workspace that does not exist.
bar_conf="$sandbox_root/bar-aerospace"
mkdir -p "$bar_conf"
{
  printf '  AEROSPACE_MAIN_WORKSPACES = "1 2 3"   # daily\n'
  printf "AEROSPACE_SIDE_WORKSPACES='4 5'\n"
  printf 'AEROSPACE_STAGE_WORKSPACES=13\n'
} >"$bar_conf/workspaces.conf"

bar_list="$(env -u SKETCHYBAR_WORKSPACES "AEROSPACE_CONFIG_DIR=$bar_conf" \
  "HOME=$sandbox_root/home" "$system_bash" -c '
    set -euo pipefail
    . "$0/lib/workspaces.sh"
    sketchybar_workspaces_from_conf "$AEROSPACE_CONFIG_DIR/workspaces.conf"
  ' "$theme_dir")"
assert_equal "1 2 3 4 5 13" "$bar_list" \
  "The bar reads every shape the AeroSpace library accepts"

rm -f "$probe"
printf 'AEROSPACE_MAIN_WORKSPACES="$(touch %s)1 2"\n' "$probe" >"$bar_conf/workspaces.conf"
bar_list="$(env -u SKETCHYBAR_WORKSPACES "AEROSPACE_CONFIG_DIR=$bar_conf" \
  "HOME=$sandbox_root/home" "$system_bash" -c '
    set -euo pipefail
    . "$0/lib/workspaces.sh"
    sketchybar_workspaces_from_conf "$AEROSPACE_CONFIG_DIR/workspaces.conf"
  ' "$theme_dir")"
assert_path_absent "$probe" "The bar must not execute a workspaces.conf value either"
assert_contains "$bar_list" 'touch' "The payload is workspace names, handled literally"

smoke_summary "$(basename "$0")"
