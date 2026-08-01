#!/usr/bin/env bash
set -euo pipefail

# Read-only health report for the public capability catalog. It deliberately
# checks outcomes (command/app + deployed config), not Homebrew ownership.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/catalog.sh"

ok=0
warnings=0
missing=0

usage() {
  cat <<'EOF'
Usage: ./bootstrap/doctor.sh [module|preset]...

Checks installed commands/apps and deployed config without changing anything.
With no arguments, checks the active named preset when one is configured;
otherwise checks every public module. Presets expand to their modules.
EOF
}

report_ok() { printf '  OK      %s\n' "$1"; ok=$((ok + 1)); }
report_warn() { printf '  MANUAL  %s\n' "$1"; warnings=$((warnings + 1)); }
report_missing() { printf '  MISSING %s\n' "$1"; missing=$((missing + 1)); }

check_path() {
  local path="$1" label="$2"
  if [ -e "$path" ] || [ -L "$path" ]; then report_ok "$label: $path"; else report_missing "$label: $path"; fi
}

check_command() {
  local command_name="$1" label="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    report_ok "$label: $(command -v "$command_name")"
  else
    report_missing "$label: command '$command_name'"
  fi
}

check_app() {
  local app="$1" label="$2"
  if [ -d "/Applications/$app.app" ] || [ -d "$HOME/Applications/$app.app" ]; then
    report_ok "$label: $app.app"
  else
    report_missing "$label: $app.app"
  fi
}

doctor_module() {
  local module="$1"
  printf '\n%s — %s\n' "$module" "$(catalog_module_description "$module")"
  case "$module" in
    workspace)
      check_command aerospace AeroSpace
      check_path "$HOME/.aerospace.toml" 'generated layout'
      check_path "$HOME/.config/aerospace" 'workspace config'
      report_warn 'AeroSpace needs Accessibility permission'
      ;;
    bar)
      check_command sketchybar SketchyBar
      check_path "$HOME/.config/sketchybar/sketchybarrc" 'bar config'
      ;;
    borders)
      check_command borders Borders
      check_path "$HOME/.config/borders/bordersrc" 'border config'
      report_ok 'Borders is intentionally not started by default'
      ;;
    capslock)
      check_app Karabiner-Elements Karabiner
      check_path "$HOME/.config/karabiner/karabiner.json" 'Karabiner config'
      report_warn 'Karabiner needs its Driver Extension and Input Monitoring permission'
      ;;
    automation)
      check_app Hammerspoon Hammerspoon
      check_path "$HOME/.hammerspoon/init.lua" 'automation config'
      report_warn 'Hammerspoon needs Accessibility and Automation permission'
      ;;
    ai)
      check_path "$HOME/.config/ai-router/ai-router.sh" 'AI router'
      ;;
    notifications)
      check_path "$HOME/.config/sketchybar/plugins/ai_app_notifications.sh" 'notification plugin'
      report_warn 'SketchyBar needs Full Disk Access to read macOS notification metadata'
      ;;
    recording)
      check_path "$HOME/.hammerspoon/screencast.lua" 'recording automation'
      report_warn 'The capture app, not this preset, needs Screen Recording permission'
      ;;
    gestures)
      check_app BetterTouchTool BetterTouchTool
      report_warn 'BetterTouchTool is paid after its trial and needs Accessibility/Input Monitoring'
      ;;
    terminal)
      check_command kaku Kaku
      check_path "$HOME/.config/kaku/kaku.lua" 'Kaku config'
      ;;
    warp)
      check_app Warp Warp
      check_path "$HOME/.warp/keybindings.yaml" 'Warp config'
      report_warn 'Warp is closed source and may require an account'
      ;;
    shell)
      check_path "$HOME/.zshenv" 'zsh entrypoint'
      check_path "$HOME/.config/zsh/.zshrc" 'zsh config'
      check_command starship Starship
      check_command yazi Yazi
      ;;
    sublime)
      check_path "$HOME/Library/Application Support/Sublime Text/Packages/User/Terminal.sublime-settings" 'Sublime terminal config'
      ;;
    media)
      check_command mpv mpv
      check_path "$HOME/.config/mpv/mpv.conf" 'mpv config'
      ;;
    skills)
      check_path "$HOME/.agents/skills" 'skills directory'
      # `npx skills` is only needed for other people's skills, so its absence is
      # a note rather than something missing.
      if command -v npx >/dev/null 2>&1; then
        report_ok "npx available for ./bootstrap/skills.sh: $(command -v npx)"
      else
        report_warn 'npx is not installed; ./bootstrap/skills.sh cannot fetch third-party skills'
      fi
      ;;
    gui-path)
      check_path "$HOME/Library/LaunchAgents/com.ai-first-dotfiles.gui-path.plist" 'GUI PATH launch agent'
      ;;
  esac
}

requested=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) requested+=("$1") ;;
  esac
  shift
done

profile_path="${AI_FIRST_PROFILE_PATH:-$HOME/.config/ai-first/profile.conf}"
active_preset=''
if [ -r "$profile_path" ]; then
  active_preset="$(ai_first_profile_conf_get "$profile_path" AI_FIRST_PRESET 2>/dev/null || true)"
  printf 'Active profile: %s (%s)\n' "${active_preset:-custom}" "$profile_path"
elif [ -d "$HOME/.config/ai-first/modules/custom" ]; then
  active_preset='custom'
  printf 'Active profile: custom (module-only composition)\n'
else
  printf 'Active profile: legacy defaults (no %s)\n' "$profile_path"
fi

# Module preferences are only read from modules/<active profile>. Anything under
# another scope is inert, and inert is indistinguishable from broken: the module
# is installed, its permission is granted, and its feature flag never arrives.
#
# Reported as MANUAL rather than MISSING on purpose - nothing here is damaged,
# and flipping doctor's exit status on an existing install would be worse than
# the thing being reported.
report_unread_overlay_scopes() {
  local modules_dir="$HOME/.config/ai-first/modules" scope_dir scope
  local active="${active_preset:-custom}" found=0

  [ -d "$modules_dir" ] || return 0
  for scope_dir in "$modules_dir"/*; do
    [ -d "$scope_dir" ] || continue
    scope="${scope_dir##*/}"
    [ "$scope" != "$active" ] || continue
    ls "$scope_dir"/*.conf >/dev/null 2>&1 || continue
    if [ "$found" -eq 0 ]; then
      printf '\nmodule preferences — scopes the active profile does not read\n'
      found=1
    fi
    report_warn "not loaded under profile \"$active\": $scope_dir"
  done
}

report_unread_overlay_scopes

if [ "${#requested[@]}" -eq 0 ]; then
  if [ "$active_preset" = 'advisor' ]; then
    requested+=(workspace bar)
    advisor_scenes="$(ai_first_profile_conf_get "$profile_path" AI_FIRST_ADVISOR_SCENES 2>/dev/null || true)"
    case " $advisor_scenes " in
      *' ai '*) requested+=(capslock automation ai) ;;
    esac
    case " $advisor_scenes " in
      *' recording '*) requested+=(automation recording) ;;
    esac
  elif [ -n "$active_preset" ] && catalog_preset_exists "$active_preset"; then
    requested+=("$active_preset")
  elif [ "$active_preset" != 'custom' ]; then
    while IFS=$'\t' read -r module _rest; do requested+=("$module"); done < <(catalog_module_records)
  fi

  if [ -n "$active_preset" ]; then
    overlay_dir="$HOME/.config/ai-first/modules/$active_preset"
    for overlay_file in "$overlay_dir"/*.conf; do
      [ -f "$overlay_file" ] || continue
      overlay_module="${overlay_file##*/}"
      overlay_module="${overlay_module%.conf}"
      catalog_module_exists "$overlay_module" && requested+=("$overlay_module")
    done
  fi

  if [ "${#requested[@]}" -eq 0 ]; then
    printf 'No public modules are recorded for the active profile.\n'
    exit 0
  fi
fi

modules=$'\n'
doctor_add_module() {
  local module="$1" dependency
  case "$modules" in *$'\n'"$module"$'\n'*) return 0 ;; esac
  for dependency in $(catalog_module_dependencies "$module"); do
    [ -n "$dependency" ] && doctor_add_module "$dependency"
  done
  modules="${modules}${module}"$'\n'
}

for choice in "${requested[@]}"; do
  if catalog_preset_exists "$choice"; then
    choices="$(catalog_preset_modules "$choice")"
  elif catalog_module_exists "$choice"; then
    choices="$choice"
  else
    printf 'Unknown module or preset: %s\n' "$choice" >&2
    exit 64
  fi
  for module in $choices; do
    doctor_add_module "$module"
  done
done

while IFS= read -r module; do
  [ -n "$module" ] && doctor_module "$module"
done <<< "$modules"

printf '\nResult: %s OK, %s manual permission/cost note(s), %s missing.\n' "$ok" "$warnings" "$missing"
[ "$missing" -eq 0 ]
