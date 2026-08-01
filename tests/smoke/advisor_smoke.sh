#!/usr/bin/env bash
set -euo pipefail

# Covers the local installation advisor and the one-shot desktop capture path.
# Detection is fixture-driven, HOME is disposable, and every mutation requires
# --apply --yes so this test also pins down the preview/no-telemetry boundary.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
setup_sh="$repo_root/bootstrap/setup.sh"
route_sh="$repo_root/home/.config/aerospace/app-route.sh"
system_bash='/bin/bash'

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/advisor-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

displays_one="$sandbox_root/displays-one"
displays_two="$sandbox_root/displays-two"
displays_three="$sandbox_root/displays-three"
apps_common="$sandbox_root/apps-common"
apps_recording="$sandbox_root/apps-recording"

cat >"$displays_one" <<'EOF'
Built-in Retina Display|1|1
EOF
cat >"$displays_two" <<'EOF'
Studio Display|1|0
Side Display|0|0
EOF
cat >"$displays_three" <<'EOF'
Studio Display|1|0
Side Display|0|0
Built-in Retina Display|0|1
EOF
cat >"$apps_common" <<'EOF'
com.jetbrains.goland
com.openai.codex
com.apple.Safari
com.tencent.xinWeChat
EOF
cat >"$apps_recording" <<'EOF'
com.jetbrains.goland
com.openai.codex
com.apple.Safari
md.obsidian
com.obsproject.obs-studio
EOF
# Three terminals, two IDEs and two browsers: the shape of a working Mac, and
# the shape that produced seven prefer routes aimed at three workspaces.
apps_many="$sandbox_root/apps-many"
cat >"$apps_many" <<'EOF'
com.apple.Terminal
dev.warp.Warp-Stable
fun.tw93.kaku
com.jetbrains.goland
com.microsoft.VSCode
com.apple.Safari
com.google.Chrome
EOF

checks=0
failures=0
pass() { checks=$((checks + 1)); }
fail() { checks=$((checks + 1)); failures=$((failures + 1)); printf 'FAIL: %s\n%s\n' "$1" "${2:-}" >&2; }
assert_equal() { if [ "$1" = "$2" ]; then pass; else fail "$3" "expected: $1\nactual:   $2"; fi; }
assert_contains() { case "$1" in *"$2"*) pass ;; *) fail "$3" "missing: $2\n$1" ;; esac; }
assert_exists() { if [ -e "$1" ] || [ -L "$1" ]; then pass; else fail "$2" "missing: $1"; fi; }
assert_missing() { if [ -e "$1" ] || [ -L "$1" ]; then fail "$2" "unexpected: $1"; else pass; fi; }
assert_file_contains() { if grep -Fq -- "$2" "$1" 2>/dev/null; then pass; else fail "$3" "$(cat "$1" 2>/dev/null || true)"; fi; }
assert_nonzero() { if [ "$1" -ne 0 ]; then pass; else fail "$2" "$3"; fi; }
assert_output_matches() { if printf '%s\n' "$1" | grep -Eq -- "$2"; then pass; else fail "$3" "no line matched: $2\n$1"; fi; }

last_status=0
last_output=''
run_advisor() {
  local home_dir="$1" displays="$2" apps="$3"
  shift 3
  last_status=0
  last_output="$(env \
    -u AI_FIRST_PROFILE_PATH \
    -u AI_FIRST_ADVISOR_ROUTES_FILE \
    -u AI_FIRST_CAPTURED_ROUTES_FILE \
    -u DOTFILES_FORCE \
    "HOME=$home_dir" \
    "XDG_STATE_HOME=$home_dir/.state" \
    "AI_FIRST_ADVISOR_DISPLAYS_FILE=$displays" \
    "AI_FIRST_ADVISOR_APPLICATIONS_FILE=$apps" \
    "$system_bash" "$setup_sh" "$@" 2>&1)" || last_status=$?
}

new_home() { mktemp -d "$sandbox_root/home.XXXXXX"; }

# Preview: detected facts and recommendations, no files and no local history.
preview_home="$(new_home)"
run_advisor "$preview_home" "$displays_one" "$apps_common" \
  recommend --non-interactive --scenes coding,ai,web,communication --config-only
assert_equal 0 "$last_status" 'read-only recommendation should succeed'
assert_contains "$last_output" 'Workspace mode:     balanced (6 workspaces)' 'four scenes on one display should recommend balanced six'
assert_contains "$last_output" 'Detected-app route suggestions: 4' 'only detected apps in selected scenes should be proposed'
assert_contains "$last_output" 'Preview only: nothing was written or installed.' 'preview must state its boundary'
if [ -z "$(find "$preview_home" -mindepth 1 -print -quit 2>/dev/null)" ]; then pass; else fail 'preview must leave HOME byte-for-byte empty'; fi

focus_home="$(new_home)"
run_advisor "$focus_home" "$displays_one" "$apps_common" \
  recommend --non-interactive --scenes coding,web --workspace-mode focus --config-only
assert_contains "$last_output" 'Workspace mode:     focus (4 workspaces)' 'explicit focus mode remains a four-workspace option'
assert_contains "$last_output" 'Main workspaces:    1 2 3 4' 'single-display focus keeps every role reachable'

dual_home="$(new_home)"
run_advisor "$dual_home" "$displays_two" "$apps_recording" \
  recommend --non-interactive --scenes coding,ai,web,writing,recording --config-only
assert_contains "$last_output" 'Workspace mode:     multitask (8 workspaces)' 'five common scenes on two displays recommend eight workspaces'
assert_contains "$last_output" 'Side workspaces:    6 7 8' 'dual-display multitask reserves a support group without pinning names'

# Non-interactive mutation needs both explicit intent flags.
guard_home="$(new_home)"
run_advisor "$guard_home" "$displays_one" "$apps_common" \
  recommend --non-interactive --apply --config-only
assert_equal 64 "$last_status" 'non-interactive apply without --yes must be refused'
assert_missing "$guard_home/.config/ai-first/profile.conf" 'refused apply must not write a profile'

# Three-display fixed desk: roles are distributed, names are pinned, and only
# apps actually found on this Mac enter the generated advisor route layer.
#
# The expected workspace mode here moved from `advanced` (10) to `multitask`
# (8), and the three groups with it. That is the point of the change, not a
# test being bent to fit: the automatic count used to add a size for the third
# display, so this same person doing this same work got ten workspaces docked
# and eight undocked. docs/choice-architecture.md and the README both promise
# the count comes from task load and that the display count only regroups it.
# Five scenes is the multitask band on any number of screens; the three
# displays still show up, in the 4/3/1 split below.
applied_home="$(new_home)"
run_advisor "$applied_home" "$displays_three" "$apps_recording" \
  recommend --non-interactive --scenes coding,ai,web,writing,recording \
  --workspace-mode auto --desk fixed --placement prefer \
  --apply --yes --config-only
assert_equal 0 "$last_status" 'fixed three-display recommendation should apply'
profile="$applied_home/.config/ai-first/profile.conf"
advisor_routes="$applied_home/.config/ai-first/advisor-routes.conf"
assert_file_contains "$profile" 'AI_FIRST_PRESET="advisor"' 'generated profile has its own overlay scope'
assert_file_contains "$profile" 'AI_FIRST_ADVISOR_WORKSPACE_MODE="multitask"' 'five scenes are the multitask band whatever is plugged in'
assert_file_contains "$profile" 'AEROSPACE_MAIN_MONITOR_NAME="Studio Display"' 'detected main display is pinned only in fixed mode'
assert_file_contains "$profile" 'AEROSPACE_SIDE_MONITOR_NAME="Side Display"' 'side display is assigned from the remaining display'
assert_file_contains "$profile" 'AEROSPACE_STAGE_MONITOR_NAME="Built-in Retina Display"' 'built-in display is the default fixed stage'
assert_file_contains "$profile" 'AEROSPACE_MAIN_WORKSPACES="1 2 3 4"' 'three displays regroup the multitask set rather than growing it'
assert_file_contains "$profile" 'AEROSPACE_SIDE_WORKSPACES="5 6 7"' 'multitask side group is generated'
assert_file_contains "$profile" 'AEROSPACE_STAGE_WORKSPACES="8"' 'multitask stage group is generated'
assert_file_contains "$advisor_routes" 'id|com.obsproject.obs-studio|stage|prefer|tiling' 'detected OBS receives a stage preference, not a global hard binding'
assert_file_contains "$advisor_routes" 'id|md.obsidian|notes|prefer|tiling' 'detected writing app receives the selected preference'
assert_missing "$applied_home/.config/aerospace/app-routes.conf" 'advisor must not replace handwritten app routes'
assert_exists "$applied_home/.state/ai-first-dotfiles/backups.tsv" 'generated files participate in the backup ledger'
doctor_output="$(HOME="$applied_home" PATH="/usr/bin:/bin" "$system_bash" "$repo_root/bootstrap/doctor.sh" 2>&1 || true)"
assert_contains "$doctor_output" 'Active profile: advisor' 'doctor recognizes an advisor-generated profile'
assert_contains "$doctor_output" 'recording —' 'doctor derives selected advisor capabilities from scenes'
case "$doctor_output" in *'gestures —'*|*'warp —'*) fail 'advisor doctor must not inspect unselected paid/closed modules' "$doctor_output" ;; *) pass ;; esac

# Tune consumes explicit feedback and backs up the generated profile.
run_advisor "$applied_home" "$displays_two" "$apps_recording" \
  tune --non-interactive --workspace-feedback fewer --apply --yes --config-only
assert_equal 0 "$last_status" 'tune should apply explicit feedback'
# One step down from the multitask profile written above, not from advanced.
assert_file_contains "$profile" 'AI_FIRST_ADVISOR_WORKSPACE_MODE="balanced"' 'fewer moves the saved mode down exactly one size'
assert_file_contains "$profile" 'AEROSPACE_STAGE_WORKSPACES="6"' 'tuned three-display stage remains semantic'
assert_file_contains "$profile" 'AEROSPACE_STAGE_MONITOR_NAME="Built-in Retina Display"' 'temporarily unplugged fixed stage is not collapsed by tune'
if compgen -G "$profile.backup_*" >/dev/null; then pass; else fail 'tune must back up the previous generated profile'; fi

# `prefer` means "send new windows of this app here". Emitting it for every app
# of a role sends three terminals to the terminal workspace and two browsers to
# the web one, so the preference the user picked becomes a pile-up. One app per
# role keeps it; the rest stay where they are opened, and the preview says so.
pileup_home="$(new_home)"
run_advisor "$pileup_home" "$displays_one" "$apps_many" \
  recommend --non-interactive --scenes coding,web --placement prefer \
  --apply --yes --config-only
assert_equal 0 "$last_status" 'a Mac with several apps per role should still apply'
pileup_routes="$pileup_home/.config/ai-first/advisor-routes.conf"
assert_equal 1 "$(grep -c '|terminal|prefer|' "$pileup_routes" || true)" 'exactly one terminal owns the terminal workspace'
assert_equal 1 "$(grep -c '|development|prefer|' "$pileup_routes" || true)" 'exactly one editor owns the development workspace'
assert_equal 1 "$(grep -c '|web|prefer|' "$pileup_routes" || true)" 'exactly one browser owns the web workspace'
assert_file_contains "$pileup_routes" 'id|com.apple.Terminal|terminal|prefer|tiling' 'the first detected app of a role is the one that keeps the preference'
assert_file_contains "$pileup_routes" 'id|dev.warp.Warp-Stable|current|follow|tiling' 'a second terminal follows the current workspace instead'
assert_file_contains "$pileup_routes" 'id|com.google.Chrome|current|follow|tiling' 'a second browser follows the current workspace instead'
# Asserted as "the role, the winner and the loser all appear on one line",
# not as a sentence: the wording changed once already, and pinning prose makes
# the test fail for a reworded message rather than for a wrong answer.
assert_output_matches "$last_output" 'terminal.*Terminal.*Warp|terminal.*Warp.*Terminal' \
  'the preview names the role, the app that kept it and the app that did not'

# A symlink means another manager owns the profile. Refuse before writing the
# second generated target so apply cannot become a partial mutation.
symlink_home="$(new_home)"
mkdir -p "$symlink_home/.config/ai-first"
printf 'external\n' >"$symlink_home/external-profile"
ln -s "$symlink_home/external-profile" "$symlink_home/.config/ai-first/profile.conf"
run_advisor "$symlink_home" "$displays_one" "$apps_common" \
  recommend --non-interactive --scenes coding,web --apply --yes --config-only
assert_nonzero "$last_status" 'symlink-owned profile must be refused' "$last_output"
assert_equal 'external' "$(cat "$symlink_home/.config/ai-first/profile.conf")" 'symlink target content must survive refusal'
assert_missing "$symlink_home/.config/ai-first/advisor-routes.conf" 'preflight refusal must happen before any companion file is written'

# Capture the desktop as it exists now. Finder is skipped because it already
# has a handwritten follow rule; a multi-workspace browser becomes follow;
# a stable IDE becomes a semantic development preference.
capture_home="$(new_home)"
mkdir -p "$capture_home/.config/aerospace" "$capture_home/.config/ai-first"
cp "$repo_root/home/.config/aerospace/app-routes.conf" "$capture_home/.config/aerospace/app-routes.conf"
cp "$profile" "$capture_home/.config/ai-first/profile.conf"
windows="$sandbox_root/windows"
cat >"$windows" <<'EOF'
xcom.jetbrains.goland	GoLand	1	tiling
xcom.jetbrains.goland	GoLand	1	tiling
xcom.apple.Safari	Safari	4	tiling
xcom.apple.Safari	Safari	5	tiling
xcom.apple.finder	Finder	1	floating
EOF

last_status=0
last_output="$(env \
  "HOME=$capture_home" \
  "APP_ROUTES_FILE=$capture_home/.config/aerospace/app-routes.conf" \
  "AI_FIRST_PROFILE_LIB=$repo_root/home/.config/ai-first/lib/profile.sh" \
  "AI_FIRST_PROFILE_PATH=$capture_home/.config/ai-first/profile.conf" \
  "AI_FIRST_CAPTURED_ROUTES_FILE=$capture_home/.config/ai-first/captured-routes.conf" \
  "AEROSPACE_CAPTURE_WINDOWS_FILE=$windows" \
  "AEROSPACE_CONFIG_PATH=$capture_home/.aerospace.toml" \
  "APP_ROUTE_NOTIFY=0" \
  "$system_bash" "$route_sh" capture-current --policy fixed 2>&1)" || last_status=$?
assert_equal 0 "$last_status" 'capture preview should succeed without AeroSpace running'
assert_contains "$last_output" 'Captured route proposal (2 app(s))' 'capture skips handwritten Finder and groups the other apps'
assert_contains "$last_output" 'com.apple.Safari' 'multi-workspace browser is visible in capture preview'
assert_missing "$capture_home/.config/ai-first/captured-routes.conf" 'capture preview writes nothing'

last_status=0
last_output="$(env \
  "HOME=$capture_home" \
  "APP_ROUTES_FILE=$capture_home/.config/aerospace/app-routes.conf" \
  "AI_FIRST_PROFILE_LIB=$repo_root/home/.config/ai-first/lib/profile.sh" \
  "AI_FIRST_PROFILE_PATH=$capture_home/.config/ai-first/profile.conf" \
  "AI_FIRST_CAPTURED_ROUTES_FILE=$capture_home/.config/ai-first/captured-routes.conf" \
  "AEROSPACE_CAPTURE_WINDOWS_FILE=$windows" \
  "AEROSPACE_CONFIG_PATH=$capture_home/.aerospace.toml" \
  "APP_ROUTE_NOTIFY=0" \
  "$system_bash" "$route_sh" capture-current --policy fixed --apply 2>&1)" || last_status=$?
assert_equal 0 "$last_status" 'capture apply should save the reviewed snapshot'
captured="$capture_home/.config/ai-first/captured-routes.conf"
assert_file_contains "$captured" 'id|com.jetbrains.goland|development|fixed|tiling' 'stable IDE capture uses its semantic role and requested strength'
assert_file_contains "$captured" 'id|com.apple.Safari|current|follow|tiling' 'an app seen across workspaces stays where opened'
if grep -Fq 'com.apple.finder' "$captured"; then fail 'capture must not duplicate a handwritten Finder rule'; else pass; fi

# Priority is handwritten > captured > advisor > shipped pack.
priority_user="$sandbox_root/priority-user"
priority_advisor="$sandbox_root/priority-advisor"
priority_captured="$sandbox_root/priority-captured"
printf '# none\n' >"$priority_user"
printf 'id|com.jetbrains.goland|ai|prefer|floating\n' >"$priority_advisor"
printf 'id|com.jetbrains.goland|development|fixed|tiling\n' >"$priority_captured"
priority="$(env \
  "HOME=$capture_home" \
  "AI_FIRST_PROFILE_LIB=$repo_root/home/.config/ai-first/lib/profile.sh" \
  "AI_FIRST_PROFILE_PATH=$capture_home/.config/ai-first/profile.conf" \
  "AI_FIRST_APP_ROUTES_FILE=$priority_user" \
  "AI_FIRST_ADVISOR_ROUTES_FILE=$priority_advisor" \
  "AI_FIRST_CAPTURED_ROUTES_FILE=$priority_captured" \
  "$system_bash" -c 'source "$1/home/.config/aerospace/app-defaults.sh"; aerospace_route_for_window com.jetbrains.goland GoLand' _ "$repo_root")"
assert_equal 'development|fixed|tiling|1' "$priority" 'captured route must beat install-time advice'
printf 'id|com.jetbrains.goland|current|follow|floating\n' >"$priority_user"
priority="$(env \
  "HOME=$capture_home" \
  "AI_FIRST_PROFILE_LIB=$repo_root/home/.config/ai-first/lib/profile.sh" \
  "AI_FIRST_PROFILE_PATH=$capture_home/.config/ai-first/profile.conf" \
  "AI_FIRST_APP_ROUTES_FILE=$priority_user" \
  "AI_FIRST_ADVISOR_ROUTES_FILE=$priority_advisor" \
  "AI_FIRST_CAPTURED_ROUTES_FILE=$priority_captured" \
  "$system_bash" -c 'source "$1/home/.config/aerospace/app-defaults.sh"; aerospace_route_for_window com.jetbrains.goland GoLand' _ "$repo_root")"
assert_equal 'current|follow|floating|' "$priority" 'handwritten route must beat every generated layer'

bad_routes_home="$(new_home)"
mkdir -p "$bad_routes_home/.config/ai-first"
cp "$profile" "$bad_routes_home/.config/ai-first/profile.conf"
printf 'id|com.example.Bad|missing-role|prefer|tiling\n' >"$bad_routes_home/.config/ai-first/advisor-routes.conf"
bad_plan_status=0
bad_plan="$(env \
  "HOME=$bad_routes_home" \
  "AI_FIRST_PROFILE_LIB=$repo_root/home/.config/ai-first/lib/profile.sh" \
  "AI_FIRST_PROFILE_PATH=$bad_routes_home/.config/ai-first/profile.conf" \
  "$system_bash" "$repo_root/home/.config/aerospace/plan.sh" --check 2>&1)" || bad_plan_status=$?
assert_nonzero "$bad_plan_status" 'plan --check must reject invalid generated advice' "$bad_plan"
assert_contains "$bad_plan" 'Advisor route is invalid' 'plan names the generated layer that needs correction'

if [ "$failures" -gt 0 ]; then
  printf 'advisor_smoke.sh: %s/%s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'advisor_smoke.sh: ok (%s checks)\n' "$checks"
