#!/usr/bin/env bash
set -euo pipefail

AEROSPACE="${AEROSPACE:-/opt/homebrew/bin/aerospace}"

main_monitor_name="PHL 279C9"
side_monitor_name="24V5C2"
stage_monitor_name="Built-in Retina Display"
main_workspaces=(1 2 3 4 5 6)
side_workspaces=(7 8 9 10 11 12)
stage_workspaces=(13)

monitor_lines="$("$AEROSPACE" list-monitors --format '%{monitor-id}	%{monitor-name}')"

monitor_id_for_name() {
    local name="$1"
    awk -F '	' -v name="$name" '$2 == name { print $1; exit }' <<<"$monitor_lines"
}

workspaces_for_monitor() {
    local monitor_id="$1"
    "$AEROSPACE" list-workspaces --monitor "$monitor_id" --format '%{workspace}' | tr '\n' ' '
}

contains_workspace() {
    local haystack=" $1 "
    local needle="$2"
    [[ "$haystack" == *" $needle "* ]]
}

print_array() {
    local first=1
    local item
    for item in "$@"; do
        if [ "$first" -eq 1 ]; then
            printf '%s' "$item"
            first=0
        else
            printf ' %s' "$item"
        fi
    done
}

issues=0
main_monitor_id="$(monitor_id_for_name "$main_monitor_name")"
side_monitor_id="$(monitor_id_for_name "$side_monitor_name")"
stage_monitor_id="$(monitor_id_for_name "$stage_monitor_name")"

printf 'Detected monitors:\n%s\n\n' "$monitor_lines"

if [ -z "$main_monitor_id" ]; then
    printf 'WARN: main monitor "%s" is not connected.\n' "$main_monitor_name"
    issues=$((issues + 1))
else
    main_actual="$(workspaces_for_monitor "$main_monitor_id")"
    printf 'Main monitor %s (%s): %s\n' "$main_monitor_name" "$main_monitor_id" "$main_actual"
    for workspace in "${main_workspaces[@]}"; do
        if ! contains_workspace "$main_actual" "$workspace"; then
            printf 'WARN: workspace %s is not on main monitor %s.\n' "$workspace" "$main_monitor_name"
            issues=$((issues + 1))
        fi
    done
fi

if [ -z "$side_monitor_id" ]; then
    printf 'WARN: side monitor "%s" is not connected.\n' "$side_monitor_name"
    issues=$((issues + 1))
else
    side_actual="$(workspaces_for_monitor "$side_monitor_id")"
    printf 'Side monitor %s (%s): %s\n' "$side_monitor_name" "$side_monitor_id" "$side_actual"
    for workspace in "${side_workspaces[@]}"; do
        if ! contains_workspace "$side_actual" "$workspace"; then
            printf 'WARN: workspace %s is not on side monitor %s.\n' "$workspace" "$side_monitor_name"
            issues=$((issues + 1))
        fi
    done
fi

if [ -z "$stage_monitor_id" ]; then
    printf 'WARN: stage monitor "%s" is not connected.\n' "$stage_monitor_name"
    issues=$((issues + 1))
else
    stage_actual="$(workspaces_for_monitor "$stage_monitor_id")"
    printf 'Stage monitor %s (%s): %s\n' "$stage_monitor_name" "$stage_monitor_id" "$stage_actual"
    for workspace in "${stage_workspaces[@]}"; do
        if ! contains_workspace "$stage_actual" "$workspace"; then
            printf 'WARN: workspace %s is not on stage monitor %s.\n' "$workspace" "$stage_monitor_name"
            issues=$((issues + 1))
        fi
    done
fi

printf '\nExpected: '
print_array "${main_workspaces[@]}"
printf ' on %s; ' "$main_monitor_name"
print_array "${side_workspaces[@]}"
printf ' on %s; ' "$side_monitor_name"
print_array "${stage_workspaces[@]}"
printf ' on %s.\n' "$stage_monitor_name"

if [ "$issues" -eq 0 ]; then
    printf 'OK: workspace layout matches the current monitor profile.\n'
else
    printf 'Found %s display layout issue(s).\n' "$issues"
    exit 1
fi
