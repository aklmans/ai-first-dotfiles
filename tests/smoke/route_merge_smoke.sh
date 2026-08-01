#!/usr/bin/env bash
set -euo pipefail

# Pins the four-layer route lookup, and one silent corruption inside it.
#
# A handwritten app-routes.conf record may be a legacy four-column, layout-only
# row (`id|X|-|floating`). That means "I care about the shape of this window,
# not where it goes", so the target is merged in from whichever lower layer has
# one: captured desktop, then advisor, then the shipped pack.
#
# That merge was built with `awk '{ printf "...%s\\n", ... }'`. Inside a
# single-quoted awk program `\\n` is a literal backslash followed by n, not a
# newline, so the merged workspace came out as `5\n`. Nothing validated it: the
# clamp fell through to "the last configured workspace", so the window opened on
# workspace 6 instead of 5, and the rendered TOML carried
# `move-node-to-workspace 5\n` - a command AeroSpace cannot run, which tomllib
# happily accepts as a valid string.
#
# So this file asserts the merged data, the resolved workspace and the rendered
# TOML separately. Any one of them alone would have missed it.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/assert.sh
. "$repo_root/tests/smoke/lib/assert.sh"

system_bash="/bin/bash"
if [ ! -x "$system_bash" ]; then
  printf 'Missing %s; route resolution must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/route-merge-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

home_dir="$sandbox_root/home"
mkdir -p "$home_dir/.config"
cp -R "$repo_root/home/.config/aerospace" "$home_dir/.config/aerospace"
cp -R "$repo_root/home/.config/ai-first" "$home_dir/.config/ai-first"

# Six workspaces, notes on 5, the last workspace is 6. That gap is what makes
# the corruption visible: a fall-through lands on 6, the correct answer is 5.
cat >"$home_dir/.config/ai-first/profile.conf" <<'EOF'
AI_FIRST_PRESET="minimal"
AI_FIRST_APP_ROUTING="1"
AI_FIRST_ROUTING_PACK="suggested"
AEROSPACE_MAIN_WORKSPACES="1 2 3 4 5 6"
AEROSPACE_SIDE_WORKSPACES=""
AEROSPACE_STAGE_WORKSPACES=""
AEROSPACE_WORKSPACE_ROLE_MAP="focus:1 development:1 terminal:2 ai:3 support:3 web:4 communication:4 notes:5 utility:6 media:6 stage:6"
EOF

routes_conf="$home_dir/.config/aerospace/app-routes.conf"
captured_conf="$home_dir/.config/ai-first/captured-routes.conf"
advisor_conf="$home_dir/.config/ai-first/advisor-routes.conf"

# Swallows the callee's exit status on purpose. A route lookup is *expected* to
# fail in some of the cases below, and under `set -e` a failing command
# substitution inside an assignment kills the whole suite - which would report
# the first broken assertion and hide every one after it.
in_home() {
  env -u AI_FIRST_APP_ROUTES_FILE \
      -u AI_FIRST_CAPTURED_ROUTES_FILE \
      -u AI_FIRST_ADVISOR_ROUTES_FILE \
      -u AI_FIRST_ROUTING_PACK \
      "HOME=$home_dir" "$system_bash" -c '
    . "$HOME/.config/aerospace/app-defaults.sh"
    "$@"
  ' _ "$@" 2>/dev/null || true
}

# --- the legacy layout-only merge -------------------------------------------
#
# The shipped `suggested` pack routes md.obsidian to the notes role, which this
# profile maps to workspace 5.

printf 'id|md.obsidian|-|tiling\n' >"$routes_conf"
rm -f "$captured_conf" "$advisor_conf"

merged="$(in_home aerospace_route_for_window md.obsidian Obsidian)"
assert_equal 'notes|prefer|tiling|5' "$merged" \
  'a layout-only handwritten row takes its target from the pack and its layout from itself'

# `*'\n'*` is a literal backslash followed by n, which is exactly what the
# doubled escape used to append.
case "$merged" in
  *'\n'*) fail 'the merged route must not carry a literal backslash-n' "[$merged]" ;;
  *) pass ;;
esac

workspace_field="$(in_home aerospace_route_field md.obsidian Obsidian workspace)"
assert_equal '5' "$workspace_field" 'the merged workspace field is plain data'

resolved="$(in_home default_workspace_for_window md.obsidian Obsidian '')"
assert_equal '5' "$resolved" \
  'the window resolves to the pack target, not to the last configured workspace'

# --- the same route, rendered to TOML ---------------------------------------

toml="$(env "HOME=$home_dir" "$system_bash" "$home_dir/.config/aerospace/app-defaults.sh" --toml 2>/dev/null || true)"
assert_output_matches "$toml" "move-node-to-workspace 5'" \
  'the rendered rule targets workspace 5'
assert_output_lacks "$toml" 'move-node-to-workspace [0-9]+\\n' \
  'no rendered AeroSpace command may contain a literal backslash-n'
assert_output_lacks "$toml" "move-node-to-workspace [^0-9']" \
  'every rendered move command must be followed by a workspace number'

# --- four-layer priority ----------------------------------------------------
#
# Handwritten beats captured beats advisor beats the shipped pack. Peeled one
# layer at a time so a broken layer cannot hide behind the one above it.

printf 'id|md.obsidian|focus|fixed|tiling\n' >"$routes_conf"
printf 'id|md.obsidian|web|prefer|floating\n' >"$captured_conf"
printf 'id|md.obsidian|terminal|prefer|-\n' >"$advisor_conf"

assert_equal 'focus|fixed|tiling|1' "$(in_home aerospace_route_for_window md.obsidian Obsidian)" \
  'a handwritten route outranks every generated layer'

rm -f "$routes_conf"
assert_equal 'web|prefer|floating|4' "$(in_home aerospace_route_for_window md.obsidian Obsidian)" \
  'a captured desktop route outranks advisor advice and the shipped pack'

rm -f "$captured_conf"
assert_equal 'terminal|prefer||2' "$(in_home aerospace_route_for_window md.obsidian Obsidian)" \
  'advisor advice outranks the shipped pack'

rm -f "$advisor_conf"
assert_equal 'notes|prefer|tiling|5' "$(in_home aerospace_route_for_window md.obsidian Obsidian)" \
  'the shipped pack is the lowest layer'

# --- the workspace whitelist ------------------------------------------------
#
# The clamp exists to map a legacy numeric target onto a shrunken workspace
# list. It must keep doing that, and must refuse anything that is not a
# workspace name rather than landing it on the last workspace.

clamp() {
  env "HOME=$home_dir" "$system_bash" -c '
    . "$HOME/.config/aerospace/lib/layout.sh"
    if out="$(aerospace_layout_clamp_workspace "$1")"; then
      printf "%s" "$out"
    else
      printf "REFUSED"
    fi
  ' _ "$1" 2>/dev/null
}

assert_equal '5'  "$(clamp 5)"  'a configured workspace clamps to itself'
assert_equal '6'  "$(clamp 13)" 'a target past the configured list still clamps down to the last one'
assert_equal 'REFUSED' "$(clamp '5\n')"       'a workspace carrying a literal escape is refused'
assert_equal 'REFUSED' "$(clamp '5; rm -rf /')" 'a workspace carrying shell metacharacters is refused'
assert_equal 'REFUSED' "$(clamp 'a b')"        'a workspace carrying a space is refused'

smoke_summary "$(basename "$0")"
