#!/usr/bin/env bash
set -euo pipefail

# Reports whether workspaces are on the displays they are supposed to be on.
#
# It used to check three monitors by name, so on any Mac without those exact
# three displays it printed three warnings and exited 1 - which made doctor.sh
# permanently red on every machine but one, with nothing the user could do
# about it. Roles are resolved against the displays that are actually connected
# now, and roles collapse onto one display when there is only one, so a laptop
# on its own is a passing configuration rather than a broken one.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=lib/layout.sh
source "$SCRIPT_DIR/lib/layout.sh"

AEROSPACE="${AEROSPACE:-${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}}"
AEROSPACE_BIN="$AEROSPACE"

aerospace_layout_load_config
aerospace_layout_resolve

monitor_lines="$(aerospace_layout_monitor_lines)"

if [ -z "$monitor_lines" ]; then
    # Whether AeroSpace is running at all is doctor.sh's "AeroSpace server
    # responds" check. Failing here as well would report one problem twice and
    # hide the real one behind a layout complaint.
    printf 'AeroSpace reported no monitors; skipping the workspace layout check.\n'
    exit 0
fi

printf 'Detected monitors:\n%s\n\n' "$monitor_lines"

workspaces_for_monitor() {
    local monitor_id="$1"
    "$AEROSPACE" list-workspaces --monitor "$monitor_id" --format '%{workspace}' 2>/dev/null | tr '\n' ' '
}

contains_workspace() {
    local haystack=" $1 "
    local needle="$2"
    case "$haystack" in
        *" $needle "*)
            return 0
            ;;
    esac
    return 1
}

issues=0

for role in $(aerospace_layout_roles); do
    role_workspaces="$(aerospace_layout_workspaces_for_role "$role")"
    [ -n "$role_workspaces" ] || continue

    monitor_name="$(aerospace_layout_resolved_name "$role")"
    monitor_id="$(aerospace_layout_resolved_id "$role")"
    configured_name="$(aerospace_layout_monitor_name_for_role "$role")"

    if [ -z "$monitor_id" ]; then
        printf 'WARN: no display could be resolved for the %s role.\n' "$role"
        issues=$((issues + 1))
        continue
    fi

    if [ -n "$configured_name" ] && [ "$configured_name" != "$monitor_name" ]; then
        printf 'Note: %s display "%s" is not connected; the %s role is on "%s" instead.\n' \
            "$role" "$configured_name" "$role" "$monitor_name"
    fi

    actual="$(workspaces_for_monitor "$monitor_id")"
    printf '%s display %s (%s): %s\n' "$role" "$monitor_name" "$monitor_id" "$actual"

    for workspace in $role_workspaces; do
        if ! contains_workspace "$actual" "$workspace"; then
            printf 'WARN: workspace %s is not on the %s display %s.\n' "$workspace" "$role" "$monitor_name"
            issues=$((issues + 1))
        fi
    done
done

printf '\nExpected:'
for role in $(aerospace_layout_roles); do
    role_workspaces="$(aerospace_layout_workspaces_for_role "$role")"
    [ -n "$role_workspaces" ] || continue
    printf ' %s on %s;' "$role_workspaces" "$(aerospace_layout_resolved_name "$role")"
done
printf '\n'

if [ "$issues" -eq 0 ]; then
    printf 'OK: workspace layout matches the current monitor profile.\n'
    exit 0
fi

printf 'Found %s display layout issue(s).\n' "$issues"
exit 1
