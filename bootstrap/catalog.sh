#!/usr/bin/env bash
# Public capability catalog for bootstrap/setup.sh.
#
# The installer used to expose implementation-shaped profiles: "desktop",
# "extras" and "all". Those names describe how this repository is organised,
# not what a user is trying to accomplish. This catalog is the product boundary:
# every public module has one outcome, explicit dependencies and an honest cost.
#
# Keep this file compatible with the Bash 3.2 shipped by macOS. It is sourced by
# setup.sh and executed directly by smoke tests; it performs no machine changes.

catalog_module_records() {
  printf '%s\n' \
    $'workspace\tPredictable tiled workspaces\tfree/open source\tAccessibility\taerospace\t-' \
    $'bar\tWorkspace and app status bar\tfree/open source\tnone\tsketchybar\tworkspace' \
    $'borders\tFocused-window border\tfree/open source\tAccessibility\tborders\tworkspace' \
    $'capslock\tCapsLock tap Esc / hold Hyper\tfree/open source\tDriver Extension, Input Monitoring\tkarabiner\t-' \
    $'automation\tWindow and chooser automation\tfree/open source\tAccessibility, Automation\thammerspoon\tworkspace' \
    $'ai\tLocal prompts and provider adapters\tfree/open source\tnone\tai-router\t-' \
    $'notifications\tAI app attention badge\tfree/open source\tFull Disk Access for SketchyBar\tsketchybar\tbar' \
    $'recording\tScreencast window presets\tfree/open source\tAccessibility; Screen Recording only for capture\thammerspoon\tautomation' \
    $'gestures\tTrackpad workspace gestures\tpaid after trial\tAccessibility, Input Monitoring\tbettertouchtool\tworkspace' \
    $'terminal\tKaku terminal integration\tfree/open source\tnone\tkaku\t-' \
    $'warp\tWarp terminal integration\tclosed source, account\tnone\twarp\t-' \
    $'shell\tzsh, Starship, Yazi and IdeaVim\tfree/open source\tchanges ZDOTDIR\tzsh,starship,yazi,ideavim\t-' \
    $'sublime\tSublime Text terminal integration\tfree config; Sublime optional\tnone\tsublime\t-' \
    $'media\tmpv configuration\tfree/open source\tnone\tmpv\t-' \
    $'gui-path\tHomebrew tools in GUI apps\tfree/open source\tlogin-session PATH\tgui-path\t-'
}

catalog_preset_records() {
  printf '%s\n' \
    $'minimal\tA small, free desktop starting point\tworkspace,bar' \
    $'developer\tKeyboard desktop plus optional local AI workflows\tworkspace,bar,capslock,automation,ai' \
    $'author-full\tThe complete, opinionated setup maintained by the author\tgui-path,workspace,bar,borders,capslock,automation,notifications,recording,ai,shell,terminal,warp,gestures,sublime,media'
}

catalog_record_field() {
  local records="$1"
  local needle="$2"
  local field="$3"

  printf '%s\n' "$records" | /usr/bin/awk -F '\t' -v needle="$needle" -v field="$field" '
    $1 == needle { print $field; found = 1; exit }
    END { if (!found) exit 1 }
  '
}

catalog_module_exists() {
  catalog_record_field "$(catalog_module_records)" "$1" 1 >/dev/null 2>&1
}

catalog_module_field() {
  catalog_record_field "$(catalog_module_records)" "$1" "$2"
}

catalog_module_description() {
  catalog_module_field "$1" 2
}

catalog_module_cost() {
  catalog_module_field "$1" 3
}

catalog_module_permissions() {
  catalog_module_field "$1" 4
}

catalog_module_scripts() {
  catalog_module_field "$1" 5 | tr ',' ' '
}

catalog_module_dependencies() {
  local value
  value="$(catalog_module_field "$1" 6)" || return 1
  [ "$value" = "-" ] && return 0
  printf '%s\n' "$value" | tr ',' ' '
}

catalog_preset_exists() {
  catalog_record_field "$(catalog_preset_records)" "$1" 1 >/dev/null 2>&1
}

catalog_preset_description() {
  catalog_record_field "$(catalog_preset_records)" "$1" 2
}

catalog_preset_modules() {
  catalog_record_field "$(catalog_preset_records)" "$1" 3 | tr ',' ' '
}

catalog_print() {
  local id description cost permissions scripts dependencies

  printf 'Modules (combine as needed):\n\n'
  while IFS=$'\t' read -r id description cost permissions scripts dependencies; do
    printf '  %-14s %s\n' "$id" "$description"
    printf '  %-14s cost: %s; permissions: %s\n' '' "$cost" "$permissions"
  done < <(catalog_module_records)

  printf '\nPresets (shortcuts, never required):\n\n'
  while IFS=$'\t' read -r id description scripts; do
    printf '  %-14s %s\n' "$id" "$description"
    printf '  %-14s modules: %s\n' '' "${scripts//,/ }"
  done < <(catalog_preset_records)

  printf '\nGuided start (read-only by default):\n\n'
  printf '  %-14s %s\n' 'recommend' 'Detect this Mac, ask about common scenes, and preview a workspace plan'
  printf '  %-14s %s\n' 'tune' 'Refine an advisor-generated profile from explicit feedback'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  catalog_print
fi
