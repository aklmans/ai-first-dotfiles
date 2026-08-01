#!/usr/bin/env bash
set -euo pipefail

# Pins the display-detection paths the advisor's own suite never exercised.
#
# advisor_smoke.sh covers one, two and three displays where the third is the
# built-in screen - the author's desk. Every path that only runs off that shape
# was broken and nothing noticed:
#
#   - advisor_display_name_at used `awk -v index=`, which is a syntax error on
#     the macOS awk. It is reached whenever no display is flagged built-in (a
#     Mac Studio, or a laptop with the lid shut and three externals) and by the
#     interactive fixed-display chooser, which therefore rejected every number a
#     user could type.
#   - Because the failure was an empty string rather than an error, a `fixed`
#     desk silently ended up with stage workspaces and no stage display name,
#     and the user saw a raw awk syntax error on stderr.
#
# Workspace *counts* are deliberately not asserted here: those move when the
# advisor stops letting display count drive them. Everything below either pins a
# grouping shape under an explicit --workspace-mode, or pins display resolution,
# both of which are independent of that change.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/assert.sh
. "$repo_root/tests/smoke/lib/assert.sh"

system_bash="/bin/bash"
if [ ! -x "$system_bash" ]; then
  printf 'Missing %s; the advisor must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

setup_sh="$repo_root/bootstrap/setup.sh"
sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/advisor-displays-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

new_home() { mktemp -d "$sandbox_root/home.XXXXXX"; }

last_output=''
last_stderr=''
last_status=0

# Keeps stdout and stderr apart: several checks below are specifically about
# what does *not* appear on stderr.
run_advisor() {
  local home_dir="$1" displays="$2" apps="$3"
  shift 3
  last_status=0
  last_output="$(env \
    -u AI_FIRST_PROFILE_PATH \
    -u AI_FIRST_ADVISOR_ROUTES_FILE \
    -u AI_FIRST_CAPTURED_ROUTES_FILE \
    -u DOTFILES_FORCE \
    -u XDG_STATE_HOME \
    "HOME=$home_dir" \
    "XDG_STATE_HOME=$home_dir/.state" \
    "AI_FIRST_ADVISOR_DISPLAYS_FILE=$displays" \
    "AI_FIRST_ADVISOR_APPLICATIONS_FILE=$apps" \
    "$system_bash" "$setup_sh" "$@" 2>"$sandbox_root/stderr")" || last_status=$?
  last_stderr="$(cat "$sandbox_root/stderr" 2>/dev/null || true)"
}

no_apps="$sandbox_root/apps-none"
: >"$no_apps"

# A three-display desk with no built-in screen: a Mac Studio, or a laptop docked
# with the lid shut. This is the shape that used to hit the awk syntax error.
externals_three="$sandbox_root/displays-three-external"
cat >"$externals_three" <<'EOF'
Studio Display|1|0
DELL U2720Q|0|0
LG UltraFine|0|0
EOF

one_display="$sandbox_root/displays-one"
cat >"$one_display" <<'EOF'
Built-in Retina Display|1|1
EOF

two_displays="$sandbox_root/displays-two"
cat >"$two_displays" <<'EOF'
Studio Display|1|0
Side Display|0|0
EOF

empty_displays="$sandbox_root/displays-empty"
: >"$empty_displays"

# --- unit: advisor_display_name_at ------------------------------------------
#
# The function the awk bug lived in. Called directly because lib/advisor.sh
# documents itself as safe to source: sourcing performs no detection and writes
# nothing.

name_at() {
  env -u AI_FIRST_ADVISOR_DISPLAYS_FILE "$system_bash" -c '
    . "$1"
    advisor_display_name_at "$2" "$3"
  ' _ "$repo_root/bootstrap/lib/advisor.sh" "$externals_three" "$1" 2>"$sandbox_root/name_at.err"
}

assert_equal 'Studio Display' "$(name_at 1)" 'display 1 resolves to the first detected name'
assert_equal 'DELL U2720Q'    "$(name_at 2)" 'display 2 resolves to the second detected name'
assert_equal 'LG UltraFine'   "$(name_at 3)" 'display 3 resolves to the third detected name'
assert_equal ''               "$(name_at 4)" 'a number past the detected list resolves to nothing'
assert_equal '' "$(cat "$sandbox_root/name_at.err")" \
  'resolving a display by number must not print an awk error'

# A name with spaces is the normal case for a display, not an edge case.
assert_equal 'Studio Display' "$(name_at 1)" 'a display name containing spaces survives resolution'

# --- unit: role defaults on a desk with no built-in display ------------------

role_default() {
  env -u AI_FIRST_ADVISOR_DISPLAYS_FILE "$system_bash" -c '
    . "$1"
    "$2" "$3"
  ' _ "$repo_root/bootstrap/lib/advisor.sh" "$1" "$externals_three" 2>/dev/null
}

assert_equal 'Studio Display' "$(role_default advisor_default_main_display)" \
  'main resolves to the display flagged as the suggested main'
assert_equal 'LG UltraFine' "$(role_default advisor_default_stage_display)" \
  'with no built-in screen, stage falls back to the last display instead of nothing'

stage_name="$(role_default advisor_default_stage_display)"
assert_not_contains "$stage_name" 'awk' 'the stage fallback must not leak an awk error into its value'

# --- fixed desk on three external displays ----------------------------------

fixed_home="$(new_home)"
run_advisor "$fixed_home" "$externals_three" "$no_apps" \
  recommend --non-interactive --scenes coding,web --desk fixed \
  --apply --yes --config-only

assert_status 0 "$last_status" 'a fixed three-external-display recommendation should apply' "$last_output"
assert_output_lacks "$last_stderr" 'awk' 'applying a fixed desk must not print an awk error'

fixed_profile="$fixed_home/.config/ai-first/profile.conf"
assert_path_exists "$fixed_profile" 'the fixed recommendation writes a profile'
assert_file_contains "$fixed_profile" 'AEROSPACE_MAIN_MONITOR_NAME="Studio Display"' \
  'fixed mode pins the main display by name'
assert_file_contains "$fixed_profile" 'AEROSPACE_SIDE_MONITOR_NAME="DELL U2720Q"' \
  'fixed mode pins the side display by name'
assert_file_contains "$fixed_profile" 'AEROSPACE_STAGE_MONITOR_NAME="LG UltraFine"' \
  'fixed mode pins the stage display even when no screen is built in'

# The regression this file exists for: stage workspaces with an empty stage
# display name is a half-pinned desk that reads exactly like a working one.
assert_file_lacks "$fixed_profile" 'AEROSPACE_STAGE_MONITOR_NAME=""' \
  'a fixed desk must never record stage workspaces against an unnamed display'

# --- grouping shape is driven by display count, at a fixed workspace count ---
#
# --workspace-mode is explicit so these stay true when the automatic count
# stops depending on how many screens are plugged in.

grouping() {
  local displays="$1" home_dir
  home_dir="$(new_home)"
  run_advisor "$home_dir" "$displays" "$no_apps" \
    recommend --non-interactive --scenes coding,web --workspace-mode balanced --config-only
}

grouping "$one_display"
assert_output_matches "$last_output" 'Main workspaces: +1 2 3 4 5 6' \
  'one display carries every balanced workspace'
assert_output_matches "$last_output" 'Side workspaces: +-' \
  'one display leaves the side group empty'

grouping "$two_displays"
assert_output_matches "$last_output" 'Main workspaces: +1 2 3 4' \
  'two displays split the balanced set four/two'
assert_output_matches "$last_output" 'Side workspaces: +5 6' \
  'two displays put the remaining balanced workspaces on the side display'

grouping "$externals_three"
assert_output_matches "$last_output" 'Main workspaces: +1 2 3' \
  'three displays split the balanced set three/two/one'
assert_output_matches "$last_output" 'Stage workspaces: +6' \
  'three displays reserve one balanced workspace as the stage'

# --- degenerate detection ---------------------------------------------------

empty_home="$(new_home)"
run_advisor "$empty_home" "$empty_displays" "$no_apps" \
  recommend --non-interactive --scenes coding --config-only
assert_status 0 "$last_status" 'an empty display fixture must not crash the advisor' "$last_stderr"
assert_output_lacks "$last_stderr" 'awk' 'the fallback display path must not print an awk error'

# Preview stays a preview even on the degenerate path.
assert_equal '' "$(find "$empty_home" -mindepth 1 -print -quit 2>/dev/null)" \
  'a preview must leave HOME untouched even when detection fell back'

smoke_summary "$(basename "$0")"
