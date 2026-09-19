#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/smoke/lib/assert.sh"
root="$(mktemp -d "${TMPDIR:-/tmp}/maintenance-smoke.XXXXXX")"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/home"
run() {
  status=0
  output="$(env -u XDG_STATE_HOME -u AI_FIRST_PROFILE_PATH -u AI_FIRST_CONFIG_DIR \
    -u AI_FIRST_PROFILE_LOADED -u DOTFILES_FORCE HOME="$root/home" \
    DOTFILES_SKIP_PREFLIGHT=1 /bin/bash "$repo_root/bootstrap/setup.sh" "$@" 2>&1)" || status=$?
}
run minimal --deploy-only
assert_equal 0 "$status" 'minimal initial deployment succeeds'
assert_path_exists "$root/home/.config/ai-first/selection.json" 'setup records explicit module selection'
run update --apply
assert_equal 0 "$status" 'selected-module update completes'
assert_path_absent "$root/home/.zshenv" 'minimal update does not add shell'
assert_path_absent "$root/home/.warp" 'minimal update does not add Warp'
assert_path_absent "$root/home/.config/mpv" 'minimal update does not add media'
run doctor
assert_contains "$output" 'selected=yes' 'doctor reports confirmed selection separately'
assert_contains "$output" 'runtime=unverified' 'doctor does not claim runtime health from files'
assert_output_lacks "$output" 'warp —' 'doctor does not report unselected modules missing'

cat >"$root/home/.config/ai-first/profile.conf" <<'EOF'
AI_FIRST_PRESET="private-test"
AI_FIRST_APP_ROUTING="1"
AI_FIRST_ROUTING_PACK="none"
AI_FIRST_FEATURE_RECORDING="1"
AI_FIRST_FEATURE_WINDOW_AUTOMATION="0"
AI_FIRST_FEATURE_AI_HOTKEYS="0"
AI_FIRST_FEATURE_NOTIFICATIONS="0"
AEROSPACE_MAIN_WORKSPACES="1 2 3 4"
AEROSPACE_SIDE_WORKSPACES="5 6 7 8"
AEROSPACE_STAGE_WORKSPACES=""
AEROSPACE_WORKSPACE_ROLE_MAP="focus:2 stage:4"
EOF
run recording --deploy-only
assert_equal 0 "$status" 'reinstalling recording does not fail'
assert_contains "$output" 'current -> proposed' 'adding a module previews preference values without applying them'
prefs="$(HOME="$root/home" /bin/bash -c '
  source "$HOME/.config/ai-first/lib/profile.sh"
  printf "%s|%s|%s|%s" "$AI_FIRST_ROUTING_PACK" "$AI_FIRST_FEATURE_WINDOW_AUTOMATION" \
    "$AI_FIRST_FEATURE_AI_HOTKEYS" "$AI_FIRST_FEATURE_NOTIFICATIONS"
')"
assert_equal 'none|0|0|0' "$prefs" 'recording reinstall preserves routing pack and quiet preferences'
assert_equal 4 "$(HOME="$root/home" /bin/bash "$root/home/.config/aerospace/recording-target.sh")" 'recording reinstall preserves stage 4'

run select workspace bar recording --apply
assert_equal 0 "$status" 'private installation explicitly adopts selected modules'
run update --apply
assert_equal 0 "$status" 'private selected update succeeds'
printf 'id|org.example.NewEditor|2|prefer|tiling\n' >>"$root/home/.config/aerospace/app-routes.conf"
status=0
HOME="$root/home" /bin/bash "$root/home/.config/aerospace/plan.sh" --check >"$root/plan.txt" 2>&1 || status=$?
assert_nonzero "$status" 'plan check detects unrendered route changes'

python3 -B "$repo_root/tests/maintenance_test.py"

smoke_summary maintenance_smoke.sh
