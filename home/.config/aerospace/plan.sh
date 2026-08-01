#!/usr/bin/env bash
set -euo pipefail

# Read-only explanation of the resolved desk, semantic workspaces and app
# routing policy. `--check` makes invalid data a non-zero result for doctor/CI.

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
route_count=0

report_issue() {
  issues=$((issues + 1))
  printf 'INVALID  %s\n' "$*"
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
aerospace_layout_resolve
for physical_role in $(aerospace_layout_roles); do
  workspaces="$(aerospace_layout_workspaces_for_role "$physical_role")"
  [ -n "$workspaces" ] || continue
  monitor="$(aerospace_layout_resolved_name "$physical_role")"
  [ -n "$monitor" ] || monitor='auto / not currently connected'
  printf '  %-6s %-36s %s\n' "$physical_role" "$monitor" "$workspaces"
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
  local kind value target field4 field5 rest resolved

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
    printf '  %-5s %-34s target=%-14s policy=%-7s layout=%-8s resolved=%s\n' \
      "$kind" "$value" "${AEROSPACE_ROUTE_TARGET:--}" "$AEROSPACE_ROUTE_POLICY" \
      "${AEROSPACE_ROUTE_LAYOUT:--}" "$resolved"
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

printf '\nResult: '
if [ "$issues" -eq 0 ]; then
  printf 'valid\n'
  exit 0
fi
printf '%s invalid setting(s)\n' "$issues"
[ "$check_only" -eq 0 ] || exit 1
exit 1
