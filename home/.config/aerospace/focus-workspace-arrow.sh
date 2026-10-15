#!/usr/bin/env bash
set -euo pipefail

# Ctrl+Left / Ctrl+Right cycle within the group of workspaces that share a
# display, so an arrow key never jumps the cursor to another monitor. The
# groups are the roles from workspaces.conf rather than the three fixed ranges
# that used to be written here, so cutting the workspace list down to five is
# one edit in one file.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=lib/layout.sh
source "$SCRIPT_DIR/lib/layout.sh"

AEROSPACE_BIN="$(aerospace_layout_bin)"

direction="${1:-}"

case "$direction" in
    next|prev) ;;
    *) exit 64 ;;
esac

focused_workspace="$("$AEROSPACE_BIN" list-workspaces --focused 2>/dev/null | head -n 1)"
role="$(aerospace_layout_role_for_workspace "$focused_workspace" || true)"
placements="$("$AEROSPACE_BIN" list-workspaces --all --format '%{workspace}%{tab}%{monitor-id}' 2>/dev/null || true)"
monitor="$(printf '%s\n' "$placements" | awk -F '\t' -v ws="$focused_workspace" '$1==ws {print $2; exit}')"

if [ -z "$role" ]; then
    "$AEROSPACE_BIN" workspace --wrap-around "$direction"
    exit 0
fi

workspaces=()
if [ -n "$monitor" ]; then
    # Dynamic display choices override the original role group. Keep the
    # configured order, but cycle only through workspaces actually here.
    on_monitor="$(printf '%s\n' "$placements" | awk -F '\t' -v id="$monitor" '$2==id {print $1}' | tr '\n' ' ')"
    for workspace in $(aerospace_layout_workspaces); do
        case " $on_monitor " in *" $workspace "*) workspaces[${#workspaces[@]}]="$workspace" ;; esac
    done
else
    for workspace in $(aerospace_layout_workspaces_for_role "$role"); do
        workspaces[${#workspaces[@]}]="$workspace"
    done
fi

# Indexed rather than `for i in "${!workspaces[@]}"`: that form needs a guard
# to survive an empty array under `set -u` on bash 3.2, and the guarded spelling
# of an index expansion is subtle enough to have already been wrong here once.
count=${#workspaces[@]}
index=0
while [ "$index" -lt "$count" ]; do
    if [ "${workspaces[$index]}" = "$focused_workspace" ]; then
        if [ "$direction" = "next" ]; then
            target_index=$(( (index + 1) % count ))
        else
            target_index=$(( (index + count - 1) % count ))
        fi

        "$AEROSPACE_BIN" workspace "${workspaces[$target_index]}"
        exit 0
    fi
    index=$((index + 1))
done

"$AEROSPACE_BIN" workspace --wrap-around "$direction"
