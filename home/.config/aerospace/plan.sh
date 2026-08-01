#!/usr/bin/env bash
set -euo pipefail

# Read-only explanation of the resolved desk, semantic workspaces and app
# routing policy, plus what the other three tools in this setup think the same
# answers are. `--check` makes invalid data a non-zero result for doctor/CI;
# without it this is a report and exits 0 whatever it found.
#
# Column note: printf pads by bytes, so a CJK app name or display name inside a
# `%-34s` throws the whole row out of line. Every table here therefore ends with
# the one field that can be wide, and pads only the ASCII fields before it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=app-defaults.sh
source "$SCRIPT_DIR/app-defaults.sh"

check_only=0
case "${1:-}" in
  '') ;;
  --check) check_only=1 ;;
  -h|--help)
    printf 'Usage: plan.sh [--check]\n'
    exit 0
    ;;
  *) printf 'Unknown option: %s\n' "$1" >&2; exit 64 ;;
esac

issues=0
drift=0
route_count=0
config_dir="${AEROSPACE_CONFIG_DIR:-$SCRIPT_DIR}"

report_issue() {
  issues=$((issues + 1))
  printf 'INVALID  %s\n' "$*"
}

# Cross-tool findings are counted apart from invalid settings: the data here is
# well-formed, it is another tool that disagrees with it.
report_drift() {
  drift=$((drift + 1))
  printf '  drift  %s\n' "$*"
}

report_ok() { printf '  ok     %s\n' "$*"; }
report_skip() { printf '  skip   %s\n' "$*"; }
report_note() { printf '  note   %s\n' "$*"; }

# One KEY="value" out of a config file, without sourcing it. Accepts the same
# two quoted forms Hammerspoon's screencast.lua and sketchybar/lib/workspaces.sh
# accept, and like both of them the last assignment wins.
plan_conf_value() {
  local file="$1" want="$2"

  [ -r "$file" ] || return 1
  /usr/bin/sed -n \
    -e "s/^[[:space:]]*$want[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*\$/\1/p" \
    -e "s/^[[:space:]]*$want[[:space:]]*=[[:space:]]*'\([^']*\)'.*\$/\1/p" \
    "$file" | /usr/bin/tail -n 1
}

plan_first_word() {
  local item
  for item in ${1:-}; do
    printf '%s' "$item"
    return 0
  done
}

plan_last_word() {
  local item last=''
  for item in ${1:-}; do
    last="$item"
  done
  printf '%s' "$last"
}

printf 'AeroSpace resolved plan\n\n'
printf 'Profile: %s\n' "${AI_FIRST_PRESET:-custom}"
printf 'App routing: %s\n' "${AI_FIRST_APP_ROUTING:-1}"
printf 'Routing pack: %s\n' "$(aerospace_routing_pack)"
printf 'Workspaces: %s\n' "$(aerospace_layout_workspaces)"

configured_pack="${AI_FIRST_ROUTING_PACK:-author}"
case "$configured_pack" in
  ''|*[!a-z0-9_-]*) report_issue "routing pack name is not data-safe: $configured_pack" ;;
  *) [ -r "$SCRIPT_DIR/routing-packs/$configured_pack.conf" ] || report_issue "routing pack does not exist: $configured_pack" ;;
esac

printf '\nDisplay roles:\n'
printf '  %-6s %-30s %s\n' 'ROLE' 'WORKSPACES' 'DISPLAY'
aerospace_layout_resolve
for physical_role in $(aerospace_layout_roles); do
  workspaces="$(aerospace_layout_workspaces_for_role "$physical_role")"
  [ -n "$workspaces" ] || continue
  monitor="$(aerospace_layout_resolved_name "$physical_role")"
  [ -n "$monitor" ] || monitor='auto / not currently connected'
  printf '  %-6s %-30s %s\n' "$physical_role" "$workspaces" "$monitor"
done

printf '\nWorkspace roles:\n'
seen_roles=' '
for entry in $AEROSPACE_WORKSPACE_ROLE_MAP; do
  case "$entry" in
    *:*) ;;
    *) report_issue "workspace role entry needs role:workspace: $entry"; continue ;;
  esac
  semantic_role="${entry%%:*}"
  workspace="${entry#*:}"
  case "$semantic_role" in
    ''|*[!a-z0-9_-]*) report_issue "invalid workspace role name: $semantic_role"; continue ;;
  esac
  case "$seen_roles" in
    *" $semantic_role "*) report_issue "duplicate workspace role: $semantic_role"; continue ;;
  esac
  seen_roles="$seen_roles$semantic_role "
  if ! aerospace_layout_workspace_is_configured "$workspace"; then
    report_issue "$semantic_role targets missing workspace $workspace"
    continue
  fi
  printf '  %-18s %s\n' "$semantic_role" "$workspace"
done

print_routes() {
  local label="$1" routes_file="$2"
  local kind value target field4 field5 rest resolved header=0

  [ -r "$routes_file" ] || return 0
  printf '\n%s routes:\n' "$label"
  while IFS='|' read -r kind value target field4 field5 rest; do
    case "$kind" in ''|'#'*) continue ;; esac
    if [ -n "${rest:-}" ]; then
      report_issue "$label route has too many fields: $kind|$value"
      continue
    fi
    case "$kind" in id|name) ;; *) report_issue "$label route has invalid match type: $kind"; continue ;; esac
    case "$value" in ''|*"'"*) report_issue "$label route has invalid match value: $value"; continue ;; esac
    if ! aerospace_normalize_route_fields "$target" "$field4" "$field5"; then
      report_issue "$label route is invalid: $kind|$value|$target|$field4${field5:+|$field5}"
      continue
    fi
    resolved="${AEROSPACE_ROUTE_WORKSPACE:--}"
    route_count=$((route_count + 1))
    if [ "$header" -eq 0 ]; then
      printf '  %-5s %-14s %-7s %-8s %-8s %s\n' 'MATCH' 'TARGET' 'POLICY' 'LAYOUT' 'RESOLVED' 'APP'
      header=1
    fi
    printf '  %-5s %-14s %-7s %-8s %-8s %s\n' \
      "$kind" "${AEROSPACE_ROUTE_TARGET:--}" "$AEROSPACE_ROUTE_POLICY" \
      "${AEROSPACE_ROUTE_LAYOUT:--}" "$resolved" "$value"
  done < "$routes_file"
  [ "$route_count" -gt 0 ] || printf '  (none)\n'
}

print_routes 'User' "$(aerospace_app_routes_file)"
route_count=0
print_routes 'Captured' "$(aerospace_captured_routes_file)"
route_count=0
print_routes 'Advisor' "$(aerospace_advisor_routes_file)"
if [ "$(aerospace_routing_pack)" != 'none' ]; then
  route_count=0
  print_routes 'Pack' "$(aerospace_routing_pack_file)"
fi

# --- cross-tool consistency --------------------------------------------------
#
# Four programs derive their behaviour from the same two config files, and a
# disagreement between them is invisible from inside any one of them: the bar
# paints chips for workspaces AeroSpace does not have, Recording Mode parks a
# window on a workspace that no longer exists, the rendered TOML is a version
# behind the config it came from. Everything below is read-only - nothing here
# writes to a config file, and karabiner.json in particular is a running
# driver's own state and is only ever read.

# The bar's workspace chips are AeroSpace workspaces. lib/workspaces.sh resolves
# them through a chain of fallbacks, so ask it rather than re-deriving them.
check_sketchybar_workspaces() {
  local sketchybar_dir="${SKETCHYBAR_CONFIG_DIR:-$HOME/.config/sketchybar}"
  local lib="$sketchybar_dir/lib/workspaces.sh"
  local pinned='' bar_list='' ours

  if [ ! -r "$lib" ]; then
    report_skip "SketchyBar is not deployed ($lib), so it has no workspace list to disagree with"
    return 0
  fi

  # theme.conf may pin the list and the environment still wins over it, which is
  # how sketchybar/lib/theme.sh resolves the same two sources.
  pinned="$(plan_conf_value "$sketchybar_dir/theme.conf" SKETCHYBAR_WORKSPACES 2>/dev/null || true)"
  [ -z "${SKETCHYBAR_WORKSPACES:-}" ] || pinned="$SKETCHYBAR_WORKSPACES"

  ours="$(aerospace_layout_workspaces)"
  bar_list="$(
    env "SKETCHYBAR_WORKSPACES=$pinned" "AEROSPACE_CONFIG_DIR=$config_dir" \
      /bin/bash -c '. "$1"; sketchybar_workspace_list' _ "$lib" 2>/dev/null || true
  )"

  if [ -z "$bar_list" ]; then
    report_drift 'SketchyBar resolves no workspace list at all, so the bar would show no workspace chips'
    return 0
  fi
  if [ "$bar_list" = "$ours" ]; then
    report_ok "SketchyBar chips match the workspace list: $ours"
    return 0
  fi
  report_drift "SketchyBar would show [$bar_list] but AeroSpace runs [$ours]"
}

# screencast.lua reads workspaces.conf directly and takes the first stage
# workspace, falling back to the last side then the last main one. A profile
# that overrides the stage list without editing workspaces.conf is exactly the
# case where Recording Mode and AeroSpace stop agreeing.
check_hammerspoon_stage() {
  local screencast="$HOME/.hammerspoon/screencast.lua"
  local conf="$config_dir/workspaces.conf"
  local picked='' stage_group

  if [ ! -r "$screencast" ]; then
    report_skip "Hammerspoon Recording Mode is not deployed ($screencast)"
    return 0
  fi
  if [ ! -r "$conf" ]; then
    report_skip "no workspaces.conf at $conf for Recording Mode to read"
    return 0
  fi

  picked="$(plan_first_word "$(plan_conf_value "$conf" AEROSPACE_STAGE_WORKSPACES || true)")"
  [ -n "$picked" ] || picked="$(plan_last_word "$(plan_conf_value "$conf" AEROSPACE_SIDE_WORKSPACES || true)")"
  [ -n "$picked" ] || picked="$(plan_last_word "$(plan_conf_value "$conf" AEROSPACE_MAIN_WORKSPACES || true)")"
  [ -n "$picked" ] || picked='13'

  stage_group="$(aerospace_layout_workspaces_for_role stage)"
  if [ -z "$stage_group" ]; then
    if aerospace_layout_workspace_is_configured "$picked"; then
      report_note "no stage workspace is configured; Recording Mode falls back to workspace $picked"
    else
      report_drift "no stage workspace is configured and Recording Mode would fall back to $picked, which is not a configured workspace"
    fi
    return 0
  fi

  case " $stage_group " in
    *" $picked "*) report_ok "Recording Mode parks on workspace $picked, inside the stage group [$stage_group]" ;;
    *) report_drift "Recording Mode would park on workspace $picked, outside the stage group [$stage_group]; $conf and the active profile disagree" ;;
  esac
}

# Rule-group descriptions out of the shipped asset. They sit one object deeper
# than the file's own indentation makes obvious, so the depth is matched
# literally against the formatting this repo ships.
karabiner_rule_descriptions() {
  /usr/bin/awk '
    /^            "description": "/ {
      text = $0
      sub(/^ *"description": "/, "", text)
      sub(/",?$/, "", text)
      print text
    }
  ' "$1"
}

check_karabiner_rules() {
  local karabiner_dir="$HOME/.config/karabiner"
  local asset="$karabiner_dir/assets/complex_modifications/capslock-ai-lite.json"
  local live="$karabiner_dir/karabiner.json"
  local description total=0 present=0

  if [ ! -d "$karabiner_dir" ]; then
    report_skip "Karabiner-Elements is not configured ($karabiner_dir)"
    return 0
  fi
  # Never counted. Karabiner-Elements creates this directory on its own, so its
  # presence does not mean anyone asked for the capslock capability, and a
  # missing asset is as likely to be a choice as a fault.
  if [ ! -r "$asset" ]; then
    report_note "the Karabiner complex modification is not deployed ($asset); ./bootstrap/setup.sh capslock installs it"
    return 0
  fi
  if [ ! -r "$live" ]; then
    report_note "$asset is deployed; there is no karabiner.json yet, so no rule is enabled"
    return 0
  fi

  while IFS= read -r description; do
    [ -n "$description" ] || continue
    total=$((total + 1))
    if /usr/bin/grep -Fq "\"description\": \"$description\"" "$live"; then
      present=$((present + 1))
    fi
  done <<EOF
$(karabiner_rule_descriptions "$asset")
EOF

  if [ "$total" -eq 0 ]; then
    report_note "could not read rule descriptions out of $asset; it is deployed but its format is unfamiliar"
    return 0
  fi
  if [ "$present" -eq "$total" ]; then
    report_ok "Karabiner: all $total shipped rule group(s) are enabled in karabiner.json"
    return 0
  fi
  # Enabling a rule is a deliberate act in the Karabiner UI, so a rule that is
  # deployed but not enabled is a choice, not a fault. Reported, never counted,
  # never written.
  report_note "Karabiner: $present of $total shipped rule group(s) are enabled in karabiner.json (enable the rest in Complex Modifications; this never writes to that file)"
}

# render-layout.sh already knows what the generated blocks should contain, and
# --check makes it say so without writing. --no-app-rules keeps it from
# re-rendering the placement block as a side effect of being asked a question.
check_aerospace_toml() {
  local toml="${AEROSPACE_CONFIG_PATH:-$HOME/.aerospace.toml}"
  local renderer="$SCRIPT_DIR/render-layout.sh"

  if [ ! -r "$toml" ]; then
    report_skip "no AeroSpace config at $toml"
    return 0
  fi
  if [ ! -r "$renderer" ]; then
    report_skip "render-layout.sh is missing, so $toml cannot be compared with the config"
    return 0
  fi

  if /bin/bash "$renderer" --check --no-app-rules "$toml" >/dev/null 2>&1; then
    report_ok "$toml matches workspaces.conf and displays.conf"
  else
    report_drift "$toml no longer matches workspaces.conf/displays.conf; run render-layout.sh to regenerate it"
  fi
}

printf '\nCross-tool consistency:\n'
check_sketchybar_workspaces
check_hammerspoon_stage
check_karabiner_rules
check_aerospace_toml

printf '\nResult: '
if [ "$issues" -eq 0 ] && [ "$drift" -eq 0 ]; then
  printf 'valid\n'
  exit 0
fi
if [ "$issues" -gt 0 ]; then
  printf '%s invalid setting(s)' "$issues"
  [ "$drift" -eq 0 ] || printf ', '
fi
[ "$drift" -eq 0 ] || printf '%s cross-tool disagreement(s)' "$drift"
printf '\n'

# Reporting is the whole job of the plain form; --check is what turns the same
# report into a non-zero result for doctor and CI. Both branches used to
# `exit 1`, which made --check a flag that changed nothing.
[ "$check_only" -eq 1 ] || exit 0
exit 1
