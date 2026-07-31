#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/bootstrap/catalog.sh"

checks=0
failures=0
sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/choice-architecture.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

pass() { checks=$((checks + 1)); }
fail() { checks=$((checks + 1)); failures=$((failures + 1)); printf 'FAIL: %s\n%s\n' "$1" "${2:-}" >&2; }
assert_equal() { if [ "$1" = "$2" ]; then pass; else fail "$3" "expected: $1\nactual:   $2"; fi; }
assert_contains() { case "$1" in *"$2"*) pass ;; *) fail "$3" "missing: $2\n$1" ;; esac; }
assert_missing() { case "$1" in *"$2"*) fail "$3" "unexpected: $2\n$1" ;; *) pass ;; esac; }

# The catalog is executable data: every dependency and installer it names must
# exist. This prevents the public menu from drifting away from implementation.
while IFS=$'\t' read -r module _description _cost _permissions scripts dependencies; do
  [ -n "$module" ] || continue
  for dependency in $(printf '%s' "$dependencies" | tr ',' ' '); do
    [ "$dependency" = '-' ] && continue
    if catalog_module_exists "$dependency"; then pass; else fail "$module has unknown dependency $dependency"; fi
  done
  for script in $(printf '%s' "$scripts" | tr ',' ' '); do
    if [ -f "$repo_root/bootstrap/install/$script.sh" ]; then pass; else fail "$module has missing installer $script"; fi
  done
done < <(catalog_module_records)

while IFS=$'\t' read -r preset _description modules; do
  for module in $(printf '%s' "$modules" | tr ',' ' '); do
    if catalog_module_exists "$module"; then pass; else fail "$preset references unknown module $module"; fi
  done
  preset_file="$repo_root/bootstrap/presets/$preset.conf"
  if [ -f "$preset_file" ]; then pass; else fail "$preset has no preference file"; continue; fi
  invalid="$(grep -vE '^[[:space:]]*(#|$)' "$preset_file" | grep -vE '^[A-Z_]+="[^"$`]*"$' || true)"
  assert_equal '' "$invalid" "$preset preference file must contain literal data only"
done < <(catalog_preset_records)

for module_file in "$repo_root"/bootstrap/modules/*.conf; do
  invalid="$(grep -vE '^[[:space:]]*(#|$)' "$module_file" | grep -vE '^[A-Z_]+="[^"$`]*"$' || true)"
  assert_equal '' "$invalid" "${module_file##*/} module overlay must contain literal data only"
done

# Profile-level behavior, tested without touching the real live config.
profile_lib="$repo_root/home/.config/ai-first/lib/profile.sh"
aerospace_dir="$repo_root/home/.config/aerospace"

minimal="$(env HOME="$sandbox_root/home-minimal" \
  AI_FIRST_PROFILE_LIB="$profile_lib" \
  AI_FIRST_PROFILE_PATH="$repo_root/bootstrap/presets/minimal.conf" \
  AEROSPACE_CONFIG_DIR="$aerospace_dir" \
  /bin/bash -c '
    source "$AEROSPACE_CONFIG_DIR/lib/layout.sh"
    aerospace_layout_load_config
    source "$AEROSPACE_CONFIG_DIR/app-defaults.sh"
    printf "preset=%s\nworkspaces=%s\nrouting=" "$AI_FIRST_PRESET" "$(aerospace_layout_workspaces)"
    if aerospace_app_routing_enabled; then printf on; else printf off; fi
    printf "\nbar-center=%s\nbar-right=%s\nterminal=%s\nnotifications=%s\n" \
      "$AI_FIRST_BAR_CENTER_ITEMS" "$AI_FIRST_BAR_RIGHT_ITEMS" \
      "$AI_FIRST_TERMINAL_APP" "$AI_FIRST_NOTIFICATION_APPS"
  ')"
assert_contains "$minimal" 'preset=minimal' 'minimal preset identity'
assert_contains "$minimal" 'workspaces=1 2 3 4 5 6' 'minimal must have six reachable workspaces'
assert_contains "$minimal" 'routing=off' 'minimal must not force the author app map'
assert_contains "$minimal" 'bar-center=' 'minimal center can be empty'
assert_missing "$minimal" 'ai_notifications' 'minimal bar must omit the notification UI'
assert_contains "$minimal" 'terminal=Terminal' 'minimal must not require Warp'
assert_contains "$minimal" 'notifications=' 'minimal notification list can be empty'

author="$(env HOME="$sandbox_root/home-author" \
  AI_FIRST_PROFILE_LIB="$profile_lib" \
  AI_FIRST_PROFILE_PATH="$repo_root/bootstrap/presets/author-full.conf" \
  AEROSPACE_CONFIG_DIR="$aerospace_dir" \
  /bin/bash -c '
    source "$AEROSPACE_CONFIG_DIR/lib/layout.sh"
    aerospace_layout_load_config
    source "$AEROSPACE_CONFIG_DIR/app-defaults.sh"
    printf "monitors=%s|%s|%s\n" "$AEROSPACE_MAIN_MONITOR_NAME" "$AEROSPACE_SIDE_MONITOR_NAME" "$AEROSPACE_STAGE_MONITOR_NAME"
    printf "groups=%s|%s|%s\n" "$AEROSPACE_MAIN_WORKSPACES" "$AEROSPACE_SIDE_WORKSPACES" "$AEROSPACE_STAGE_WORKSPACES"
    printf "obs=%s bili=%s shadow=%s shadow-layout=" \
      "$(default_workspace_rule_for_window com.obsproject.obs-studio OBS title)" \
      "$(default_workspace_rule_for_window com.bilibili.bilibiliPC Bilibili title)" \
      "$(default_workspace_rule_for_window com.blade.shadow-macos Shadow title)"
    if should_tile_window com.blade.shadow-macos Shadow title; then printf tiling; else printf other; fi
    printf "\nnotify=%s\n" "$AI_FIRST_NOTIFICATION_APPS"
  ')"
assert_contains "$author" 'monitors=PHL 279C9|24V5C2|Built-in Retina Display' 'author display ownership is preserved'
assert_contains "$author" 'groups=1 2 3 4 5 6|7 8 9 10 11 12|13' 'author workspace groups are preserved'
assert_contains "$author" 'obs=11 bili=10 shadow=2 shadow-layout=tiling' 'critical author app rules are preserved'
assert_contains "$author" 'notify=warp codex idea goland' 'notification whitelist stays limited to four apps'

# A user override wins over built-ins and is rendered as data, not executed.
routes="$sandbox_root/app-routes.conf"
printf '%s\n' 'id|com.obsproject.obs-studio|4|floating' > "$routes"
override="$(env HOME="$sandbox_root/home-route" AI_FIRST_APP_ROUTES_FILE="$routes" AEROSPACE_CONFIG_DIR="$aerospace_dir" \
  /bin/bash -c 'source "$AEROSPACE_CONFIG_DIR/app-defaults.sh"; printf "%s|" "$(default_workspace_rule_for_window com.obsproject.obs-studio OBS title)"; should_float_window com.obsproject.obs-studio OBS title && printf floating')"
assert_equal '4|floating' "$override" 'user app route must win over a shipped default'
printf '%s\n' 'name|Example.App (Beta)|5|tiling' > "$routes"
rendered_override="$(env HOME="$sandbox_root/home-route-render" AI_FIRST_APP_ROUTES_FILE="$routes" AEROSPACE_CONFIG_DIR="$aerospace_dir" \
  /bin/bash -c 'source "$AEROSPACE_CONFIG_DIR/app-defaults.sh"; emit_user_on_window_detected_rules')"
assert_contains "$rendered_override" "'^Example\\.App \\(Beta\\)$'" 'app names must be escaped before becoming TOML regexes'

# Notification selection accepts a subset but never expands beyond support.
notify="$(env HOME="$sandbox_root/home-notify" AI_FIRST_NOTIFICATION_APPS='codex unknown goland' \
  /bin/bash -c 'source "$1"; ai_first_notification_apps' _ "$repo_root/home/.config/sketchybar/lib/notifications.sh")"
assert_equal $'codex\ngoland' "$notify" 'notification config must filter to the supported whitelist'
empty_notify="$(env HOME="$sandbox_root/home-empty-notify" AI_FIRST_NOTIFICATION_APPS= \
  /bin/bash -c 'source "$1"; ai_first_notification_apps' _ "$repo_root/home/.config/sketchybar/lib/notifications.sh")"
assert_equal '' "$empty_notify" 'an empty notification selection must remain empty'

# profile.conf is parsed as literal data. It cannot execute shell, and an
# environment variable remains the highest-priority one-off override.
unsafe_profile="$sandbox_root/unsafe-profile.conf"
printf '%s\n' \
  'AI_FIRST_TERMINAL_APP="Warp"' \
  "AI_FIRST_PRESET=\"\$(touch '$sandbox_root/profile-executed')\"" > "$unsafe_profile"
profile_result="$(env HOME="$sandbox_root/home-profile" AI_FIRST_PROFILE_PATH="$unsafe_profile" \
  AI_FIRST_TERMINAL_APP=Terminal /bin/bash -c 'source "$1"; printf "%s|%s" "$AI_FIRST_TERMINAL_APP" "$AI_FIRST_PRESET"' _ "$profile_lib")"
assert_equal 'Terminal|custom' "$profile_result" 'environment must win and non-literal profile code must be ignored'
if [ -e "$sandbox_root/profile-executed" ]; then fail 'profile parsing must never execute shell'; else pass; fi
empty_override="$(env HOME="$sandbox_root/home-empty-profile" AI_FIRST_PROFILE_PATH="$unsafe_profile" \
  AI_FIRST_NOTIFICATION_APPS= /bin/bash -c 'source "$1"; printf "%s" "$AI_FIRST_NOTIFICATION_APPS"' _ "$profile_lib")"
assert_equal '' "$empty_override" 'an explicit empty environment override must stay empty'

# Deploy-only is the safe way to prove a preset becomes real runtime state.
deploy_home="$sandbox_root/deploy-home"
mkdir -p "$deploy_home"
choice_stub_dir="$sandbox_root/stub-bin"
mkdir -p "$choice_stub_dir"
printf '#!/bin/sh\nexit 1\n' > "$choice_stub_dir/aerospace"
chmod +x "$choice_stub_dir/aerospace"
deploy_output="$(HOME="$deploy_home" PATH="$choice_stub_dir:$PATH" DOTFILES_SKIP_PREFLIGHT=1 /bin/bash "$repo_root/bootstrap/setup.sh" minimal --deploy-only 2>&1)"
assert_contains "$(cat "$deploy_home/.config/ai-first/profile.conf")" 'AI_FIRST_PRESET="minimal"' 'minimal deploy writes its profile'
if find "$deploy_home" -type l -print -quit | grep -q .; then
  fail 'preset deployment must use copies, not symlinks' "$(find "$deploy_home" -type l -print)"
else
  pass
fi
assert_missing "$deploy_output" 'brew install' 'deploy-only must not install packages'

compose_output="$(HOME="$deploy_home" PATH="$choice_stub_dir:$PATH" DOTFILES_SKIP_PREFLIGHT=1 /bin/bash "$repo_root/bootstrap/setup.sh" minimal notifications --deploy-only 2>&1)"
composed_profile="$(HOME="$deploy_home" /bin/bash -c 'source "$1"; printf "%s|%s|%s" "$AI_FIRST_FEATURE_NOTIFICATIONS" "$AI_FIRST_BAR_RIGHT_ITEMS" "$AI_FIRST_NOTIFICATION_APPS"' _ "$deploy_home/.config/ai-first/lib/profile.sh")"
assert_equal '1|clock calendar battery volume ai_notifications|warp codex idea goland' "$composed_profile" \
  'an extra notification module must activate itself on top of minimal'
assert_contains "$compose_output" 'modules/minimal/notifications.conf' 'preset extras must be stored in that preset scope'

module_home="$sandbox_root/module-home"
mkdir -p "$module_home"
HOME="$module_home" PATH="$choice_stub_dir:$PATH" DOTFILES_SKIP_PREFLIGHT=1 /bin/bash "$repo_root/bootstrap/setup.sh" automation ai --deploy-only >/dev/null 2>&1
module_profile="$(HOME="$module_home" /bin/bash -c 'source "$1"; printf "%s|%s|%s|%s|%s" "$AI_FIRST_FEATURE_AI_HOTKEYS" "$AI_FIRST_FEATURE_NOTIFICATIONS" "$AI_FIRST_TERMINAL_APP" "$AI_FIRST_APP_ROUTING" "$AEROSPACE_MAIN_WORKSPACES"' _ "$module_home/.config/ai-first/lib/profile.sh")"
assert_equal '1|0|Terminal|0|1 2 3 4 5 6' "$module_profile" 'module-only composition must start neutral and enable only selected AI behavior'

scope_home="$sandbox_root/scope-home"
mkdir -p "$scope_home/modules/custom" "$scope_home/modules/minimal"
cp "$repo_root/bootstrap/presets/minimal.conf" "$scope_home/profile.conf"
cp "$repo_root/bootstrap/modules/base.conf" "$scope_home/modules/custom/00-base.conf"
cp "$repo_root/bootstrap/modules/recording.conf" "$scope_home/modules/custom/recording.conf"
scoped_profile="$(HOME="$sandbox_root/scope-user" AI_FIRST_CONFIG_DIR="$scope_home" /bin/bash -c 'source "$1"; printf "%s|%s" "$AI_FIRST_PRESET" "$AI_FIRST_FEATURE_RECORDING"' _ "$profile_lib")"
assert_equal 'minimal|0' "$scoped_profile" 'switching to a preset must ignore module choices from another scope'

doctor_output="$(HOME="$deploy_home" PATH="/usr/bin:/bin" /bin/bash "$repo_root/bootstrap/doctor.sh" notifications 2>&1 || true)"
assert_contains "$doctor_output" 'workspace —' 'doctor must include transitive workspace dependency'
assert_contains "$doctor_output" 'bar —' 'doctor must include direct bar dependency'
assert_contains "$doctor_output" 'notifications —' 'doctor must check the requested capability'
default_doctor_output="$(HOME="$deploy_home" PATH="/usr/bin:/bin" DOTFILES_SKIP_PREFLIGHT=1 \
  /bin/bash "$repo_root/bootstrap/setup.sh" doctor 2>&1 || true)"
assert_contains "$default_doctor_output" 'Active profile: minimal' 'no-argument doctor must infer the active preset'
assert_contains "$default_doctor_output" 'workspace —' 'inferred preset doctor must run without an empty-array failure'
assert_contains "$default_doctor_output" 'notifications —' 'doctor must include modules explicitly added to a preset'

custom_doctor_output="$(HOME="$module_home" PATH="/usr/bin:/bin" /bin/bash "$repo_root/bootstrap/doctor.sh" 2>&1 || true)"
assert_contains "$custom_doctor_output" 'Active profile: custom' 'doctor must recognize module-only composition'
assert_contains "$custom_doctor_output" 'ai —' 'custom doctor must inspect selected module overlays'
assert_missing "$custom_doctor_output" 'warp —' 'custom doctor must not diagnose unselected paid/closed alternatives'

HOME="$deploy_home" PATH="$choice_stub_dir:$PATH" DOTFILES_SKIP_PREFLIGHT=1 \
  /bin/bash "$repo_root/bootstrap/setup.sh" developer --deploy-only >/dev/null 2>&1
switched_profile="$(HOME="$deploy_home" /bin/bash -c 'source "$1"; printf "%s|%s" "$AI_FIRST_PRESET" "$AI_FIRST_FEATURE_NOTIFICATIONS"' _ "$deploy_home/.config/ai-first/lib/profile.sh")"
assert_equal 'developer|0' "$switched_profile" 'switching presets must ignore additions scoped to the previous preset'
if find "$deploy_home/.config/ai-first" -maxdepth 1 -name 'profile.conf.backup_*' -print -quit | grep -q .; then
  pass
else
  fail 'switching presets must back up the previous profile'
fi

if [ "$failures" -gt 0 ]; then
  printf '\nchoice_architecture_smoke.sh: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'choice_architecture_smoke.sh: ok (%s checks)\n' "$checks"
