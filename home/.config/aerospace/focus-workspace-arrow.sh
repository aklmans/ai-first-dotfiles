#!/usr/bin/env bash
set -euo pipefail

direction="${1:-}"

case "$direction" in
    next|prev) ;;
    *) exit 64 ;;
esac

focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null | head -n 1)"

case "$focused_workspace" in
    1|2|3|4|5|6)
        workspaces=(1 2 3 4 5 6)
        ;;
    7|8|9|10|11|12)
        workspaces=(7 8 9 10 11 12)
        ;;
    13)
        workspaces=(13)
        ;;
    *)
        aerospace workspace --wrap-around "$direction"
        exit 0
        ;;
esac

for i in "${!workspaces[@]}"; do
    if [ "${workspaces[$i]}" = "$focused_workspace" ]; then
        if [ "$direction" = "next" ]; then
            target_index=$(( (i + 1) % ${#workspaces[@]} ))
        else
            target_index=$(( (i + ${#workspaces[@]} - 1) % ${#workspaces[@]} ))
        fi

        aerospace workspace "${workspaces[$target_index]}"
        exit 0
    fi
done

aerospace workspace --wrap-around "$direction"
