#!/usr/bin/env bash
set -euo pipefail

# Pins where a module preference overlay is written, against where it is read.
#
# setup.sh writes ~/.config/ai-first/modules/<scope>/<module>.conf. The runtime
# reads modules/$AI_FIRST_PRESET (home/.config/ai-first/lib/profile.sh, and a
# second time in Lua in home/.hammerspoon/init.lua). The scope used to come from
# the current command line only, so the two disagreed for the most ordinary
# sequence there is:
#
#     ./bootstrap/setup.sh minimal        # profile.conf says minimal
#     ./bootstrap/setup.sh notifications  # overlay written to modules/custom/
#
# The module was installed, its Full Disk Access was granted, and its feature
# flag was never loaded by anything. `doctor` reported everything fine.
#
# Two failure shapes are asserted here, because fixing only the first one
# introduces the second:
#
#   - an overlay written where nothing reads it (the original bug)
#   - an overlay written where it *overwrites* the profile it landed next to
#     (what happens when bar.conf's neutral bar composition is dropped beside a
#     profile that had chosen its own)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/assert.sh
. "$repo_root/tests/smoke/lib/assert.sh"

system_bash="/bin/bash"
if [ ! -x "$system_bash" ]; then
  printf 'Missing %s; setup.sh must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

setup_sh="$repo_root/bootstrap/setup.sh"
sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/overlay-scope-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

new_home() { mktemp -d "$sandbox_root/home.XXXXXX"; }

# Deploy only: no packages, no services, no macOS settings.
run_setup() {
  local home_dir="$1"
  shift
  env -u XDG_STATE_HOME \
      -u AI_FIRST_PROFILE_PATH \
      -u DOTFILES_FORCE \
      "HOME=$home_dir" \
      "XDG_STATE_HOME=$home_dir/.state" \
      "DOTFILES_SKIP_PREFLIGHT=1" \
      "$system_bash" "$setup_sh" "$@" >/dev/null 2>&1 || true
}

# Reads a resolved preference the way the deployed runtime does.
profile_value() {
  local home_dir="$1" key="$2"
  env "HOME=$home_dir" "$system_bash" -c '
    . "$HOME/.config/ai-first/lib/profile.sh"
    eval "printf %s \"\${$1:-}\""
  ' _ "$key" 2>/dev/null || true
}

overlay_paths() {
  local home_dir="$1"
  (cd "$home_dir/.config/ai-first/modules" 2>/dev/null && find . -name '*.conf' | LC_ALL=C sort | sed 's|^\./||') || true
}

# --- a module added to an installed preset lands in that preset's scope ------

preset_home="$(new_home)"
run_setup "$preset_home" minimal --deploy-only
assert_file_contains "$preset_home/.config/ai-first/profile.conf" 'AI_FIRST_PRESET="minimal"' \
  'the preset records its own scope name'

run_setup "$preset_home" notifications --deploy-only
assert_path_exists "$preset_home/.config/ai-first/modules/minimal/notifications.conf" \
  'a module added later lands in the installed preset scope, not in custom'
assert_path_absent "$preset_home/.config/ai-first/modules/custom/notifications.conf" \
  'the module must not land in a scope the profile does not read'
assert_equal '1' "$(profile_value "$preset_home" AI_FIRST_FEATURE_NOTIFICATIONS)" \
  'the added module actually reaches the runtime'
assert_contains "$(profile_value "$preset_home" AI_FIRST_BAR_RIGHT_ITEMS)" 'ai_notifications' \
  'the added module contributes its bar item'

# --- the same, on a generated advisor profile -------------------------------
#
# `advisor` is not a catalog preset, so this also pins that the scope is treated
# as an opaque name rather than validated against the catalog.

advisor_home="$(new_home)"
mkdir -p "$advisor_home/.config/ai-first"
cp -R "$repo_root/home/.config/ai-first/." "$advisor_home/.config/ai-first/"
cat >"$advisor_home/.config/ai-first/profile.conf" <<'EOF'
AI_FIRST_PRESET="advisor"
AI_FIRST_TERMINAL_APP="Warp"
AI_FIRST_BAR_CENTER_ITEMS="spotify media"
AI_FIRST_BAR_RIGHT_ITEMS="clock calendar battery volume"
EOF

run_setup "$advisor_home" notifications --deploy-only
assert_path_exists "$advisor_home/.config/ai-first/modules/advisor/notifications.conf" \
  'a generated profile scope receives its overlays too'
assert_equal '1' "$(profile_value "$advisor_home" AI_FIRST_FEATURE_NOTIFICATIONS)" \
  'a module added to an advisor profile reaches the runtime'

# The regression that appears the moment overlays start loading: a module
# overlay must contribute its own preference, not restate neutral defaults over
# a choice the profile already made.
run_setup "$advisor_home" ai bar --deploy-only
assert_equal 'Warp' "$(profile_value "$advisor_home" AI_FIRST_TERMINAL_APP)" \
  'adding ai must not reset a terminal the profile had chosen'
assert_equal 'spotify media' "$(profile_value "$advisor_home" AI_FIRST_BAR_CENTER_ITEMS)" \
  'adding bar must not wipe a bar composition the profile had chosen'
assert_equal '1' "$(profile_value "$advisor_home" AI_FIRST_FEATURE_AI_HOTKEYS)" \
  'adding ai still turns its own feature on'

# --- a module already inside the preset writes no overlay at all -------------
#
# author-full puts ai_notifications in the middle of its bar. Dropping the
# neutral bar composition next to it would delete that item.

author_home="$(new_home)"
run_setup "$author_home" author-full --deploy-only
author_bar_before="$(profile_value "$author_home" AI_FIRST_BAR_RIGHT_ITEMS)"
assert_contains "$author_bar_before" 'ai_notifications' 'author-full ships an attention badge on its bar'

run_setup "$author_home" bar --deploy-only
assert_path_absent "$author_home/.config/ai-first/modules/author-full/bar.conf" \
  'a capability already inside the active preset writes no overlay'
assert_equal "$author_bar_before" "$(profile_value "$author_home" AI_FIRST_BAR_RIGHT_ITEMS)" \
  're-naming a module the preset already includes changes nothing'

# --- module-only composition keeps the custom scope and the neutral base -----

module_home="$(new_home)"
run_setup "$module_home" automation ai --deploy-only
assert_path_exists "$module_home/.config/ai-first/modules/custom/00-base.conf" \
  'module-only composition still gets the neutral base'
assert_equal '1' "$(profile_value "$module_home" AI_FIRST_FEATURE_AI_HOTKEYS)" \
  'module-only composition loads its own overlays'
assert_equal 'none' "$(profile_value "$module_home" AI_FIRST_ROUTING_PACK)" \
  'module-only composition stays on the neutral routing pack'
assert_equal '0' "$(profile_value "$module_home" AI_FIRST_FEATURE_NOTIFICATIONS)" \
  'automation alone does not silently activate notifications'

# The neutral base belongs to custom only: dropped into a named scope it would
# load after profile.conf and overwrite that preset's values.
assert_path_absent "$preset_home/.config/ai-first/modules/minimal/00-base.conf" \
  'a named preset scope never receives the neutral base'
assert_path_absent "$advisor_home/.config/ai-first/modules/advisor/00-base.conf" \
  'a generated scope never receives the neutral base'

# --- a scope name is a path segment and is validated as one ------------------

traversal_home="$(new_home)"
mkdir -p "$traversal_home/.config/ai-first"
cp -R "$repo_root/home/.config/ai-first/." "$traversal_home/.config/ai-first/"
printf 'AI_FIRST_PRESET="../../../etc"\n' >"$traversal_home/.config/ai-first/profile.conf"
run_setup "$traversal_home" notifications --deploy-only
assert_path_exists "$traversal_home/.config/ai-first/modules/custom/notifications.conf" \
  'an unusable scope name falls back to custom'
assert_equal '' "$(overlay_paths "$traversal_home" | /usr/bin/grep -F '..' || true)" \
  'no overlay path may climb out of the modules directory'

# --- --dry-run must name the path the real run writes ------------------------

preview_home="$(new_home)"
mkdir -p "$preview_home/.config/ai-first"
cp -R "$repo_root/home/.config/ai-first/." "$preview_home/.config/ai-first/"
cp "$repo_root/bootstrap/presets/minimal.conf" "$preview_home/.config/ai-first/profile.conf"

preview="$(env -u XDG_STATE_HOME -u AI_FIRST_PROFILE_PATH \
  "HOME=$preview_home" "DOTFILES_SKIP_PREFLIGHT=1" \
  "$system_bash" "$setup_sh" notifications --dry-run 2>&1 || true)"
assert_output_matches "$preview" 'modules/minimal/notifications\.conf' \
  'the preview names the scope the real run would use'
assert_output_lacks "$preview" 'modules/custom/notifications\.conf' \
  'the preview must not promise a path the real run does not write'

# --- doctor reports overlays the active profile cannot read ------------------

stale_home="$(new_home)"
run_setup "$stale_home" minimal --deploy-only
mkdir -p "$stale_home/.config/ai-first/modules/custom"
cp "$repo_root/bootstrap/modules/recording.conf" "$stale_home/.config/ai-first/modules/custom/recording.conf"

doctor_output="$(env "HOME=$stale_home" "PATH=/usr/bin:/bin" \
  "$system_bash" "$repo_root/bootstrap/doctor.sh" 2>&1 || true)"
assert_contains "$doctor_output" 'modules/custom' \
  'doctor names an overlay directory the active profile does not read'
assert_output_matches "$doctor_output" 'MANUAL .*not loaded under profile' \
  'an unread overlay is a manual note, not a missing file'

smoke_summary "$(basename "$0")"
