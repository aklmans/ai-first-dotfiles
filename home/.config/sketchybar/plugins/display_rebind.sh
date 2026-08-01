#!/usr/bin/env bash

# Re-points the workspace chips at the displays that are connected now.
#
# Runs on SketchyBar's `display_change`. The chips carry a real display id -
# workspaces 7-12 belong on the side monitor whether or not it is the one you
# are looking at - and that id is resolved when the bar is configured. Plugging a
# monitor in or pulling one out therefore left every chip bound to an
# arrangement that no longer existed, and the fix was to run
# `sketchybar --reload` by hand, which is not a thing anyone should have to know.
#
# Only the bindings are recomputed. Which workspaces exist has not changed - a
# display is not a workspace - so nothing is added or removed, and the two
# lookups this needs are re-asked rather than reused: aerospace_layout_resolve()
# and the display resolver both answer from state captured before the monitor
# moved.

AEROSPACE_CONFIG_DIR="${AEROSPACE_CONFIG_DIR:-$HOME/.config/aerospace}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"

source "$CONFIG_DIR/lib/theme.sh"
source "$CONFIG_DIR/lib/workspaces.sh"
source "$CONFIG_DIR/lib/display-resolver.sh"

if [ -r "$AEROSPACE_CONFIG_DIR/lib/layout.sh" ]; then
    # shellcheck source=/dev/null
    source "$AEROSPACE_CONFIG_DIR/lib/layout.sh"
    aerospace_layout_load_config
    aerospace_layout_resolve
fi

args=()
while read -r workspace display; do
    [ -n "$workspace" ] || continue
    [ -n "$display" ] || continue
    args+=(--set "space.$workspace" "display=$display")
done <<EOF
$(sketchybar_workspace_display_bindings)
EOF

# Nothing resolved is not an error worth a message on a machine that has just
# had its last external display unplugged mid-repaint; the next event will ask
# again.
[ "${#args[@]}" -gt 0 ] || exit 0

sketchybar "${args[@]}" >/dev/null 2>&1 || true
