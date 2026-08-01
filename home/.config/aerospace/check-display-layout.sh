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

# Which connected display currently shows this workspace, if any. Asking
# AeroSpace beats re-deriving it: it is the one that placed it.
monitor_for_workspace() {
    local workspace="$1" id
    for id in $(printf '%s\n' "$monitor_lines" | while IFS= read -r line; do
        [ -n "$line" ] || continue
        printf '%s\n' "${line%%	*}"
    done); do
        if contains_workspace "$(workspaces_for_monitor "$id")" "$workspace"; then
            printf '%s\n' "$id"
            return 0
        fi
    done
    return 1
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

    fell_back=0
    if [ -n "$configured_name" ] && [ "$configured_name" != "$monitor_name" ]; then
        fell_back=1
        printf 'Note: %s display "%s" is not connected; the %s role falls back.\n' \
            "$role" "$configured_name" "$role"
    fi

    actual="$(workspaces_for_monitor "$monitor_id")"
    printf '%s display %s (%s): %s\n' "$role" "$monitor_name" "$monitor_id" "$actual"

    for workspace in $role_workspaces; do
        if contains_workspace "$actual" "$workspace"; then
            continue
        fi

        # A role whose own display is missing has no single right answer, and
        # insisting on one made a correct machine red. render-layout.sh does not
        # emit a monitor for these: it emits a list, and AeroSpace walks it. The
        # two do not even agree on the words - `main` and `side` here are roles
        # this repo assigns, while AeroSpace's `main` and `secondary` are about
        # which display macOS put the menu bar on. With the lid shut on a desk
        # of two externals, this said stage lands on the side display and
        # AeroSpace put workspace 13 on the other one. Both are on the list, so
        # both are right, and re-deriving the choice here can only disagree.
        if [ "$fell_back" -eq 1 ]; then
            if [ -n "$(monitor_for_workspace "$workspace")" ]; then
                continue
            fi
            printf 'WARN: workspace %s is on no connected display.\n' "$workspace"
        else
            printf 'WARN: workspace %s is not on the %s display %s.\n' "$workspace" "$role" "$monitor_name"
        fi
        issues=$((issues + 1))
    done
done

printf '\nExpected:'
for role in $(aerospace_layout_roles); do
    role_workspaces="$(aerospace_layout_workspaces_for_role "$role")"
    [ -n "$role_workspaces" ] || continue
    configured_name="$(aerospace_layout_monitor_name_for_role "$role")"
    monitor_name="$(aerospace_layout_resolved_name "$role")"
    # Naming one display for a role that fell back is the same claim the loop
    # above stopped making, and printing it anyway left the summary arguing with
    # the note four lines earlier.
    if [ -n "$configured_name" ] && [ "$configured_name" != "$monitor_name" ]; then
        printf ' %s on any connected display;' "$role_workspaces"
    else
        printf ' %s on %s;' "$role_workspaces" "$monitor_name"
    fi
done
printf '\n'

if [ "$issues" -eq 0 ]; then
    printf 'OK: workspace layout matches the current monitor profile.\n'
    exit 0
fi

printf 'Found %s display layout issue(s).\n' "$issues"
exit 1
