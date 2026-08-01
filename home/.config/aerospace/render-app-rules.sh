#!/usr/bin/env bash
set -euo pipefail

# Renders the app placement and floating rules in ~/.aerospace.toml from
# app-defaults.sh, which is where they are actually maintained.
#
# Usage: render-app-rules.sh [path-to-aerospace.toml]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${1:-$HOME/.aerospace.toml}"
RULES_FILE="$(mktemp)"
OUTPUT_FILE="$(mktemp)"

cleanup() {
    rm -f "$RULES_FILE" "$OUTPUT_FILE"
}
trap cleanup EXIT

"$SCRIPT_DIR/app-defaults.sh" --toml > "$RULES_FILE"

awk -v rules_file="$RULES_FILE" '
BEGIN {
    while ((getline line < rules_file) > 0) {
        rules = rules line ORS
    }
}
/^# Application placement and floating rules\./ {
    printf "%s\n", rules
    skip = 1
    next
}
/^\[mode\.main\.binding\]/ {
    skip = 0
}
!skip {
    print
}
' "$CONFIG_PATH" > "$OUTPUT_FILE"

# tomllib arrived in python 3.11. Skipping the check on an older interpreter is
# better than refusing to render for everyone who has one.
if command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' >/dev/null 2>&1; then
    python3 -c 'import pathlib, sys, tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' "$OUTPUT_FILE"
fi

if cmp -s "$OUTPUT_FILE" "$CONFIG_PATH"; then
    printf 'Unchanged: %s already matches app-defaults.sh\n' "$CONFIG_PATH"
    exit 0
fi

# render-layout.sh calls this at the end of its own pass and has already kept a
# copy of the file as it was before either renderer touched it. A second backup
# one second later is of content the first renderer just generated, which is not
# what anyone would want to recover.
backup_path="${AEROSPACE_RENDER_BACKUP:-}"
if [ -z "$backup_path" ] || [ ! -e "$backup_path" ]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup_path="$CONFIG_PATH.bak-$stamp-render-app-rules"
    cp "$CONFIG_PATH" "$backup_path"
fi
cp "$OUTPUT_FILE" "$CONFIG_PATH"
printf 'Rendered app rules into %s (previous file kept at %s)\n' \
    "$CONFIG_PATH" "$backup_path"

# Rendering a file nothing has read yet is not applying it, and this is the
# command README names for "I edited app-routes.conf, now make it real". Both
# tools have to be told, in this order:
#
#   AeroSpace   reads the rendered TOML
#   Hammerspoon reads app-routes.conf itself, once, at init
#
# Leaving Hammerspoon out is worse than leaving it stale. It falls back to
# inheriting the focused workspace for any app it has no route for, so a route
# added by hand takes effect in AeroSpace and is then overridden by Hammerspoon
# a moment later - the window lands on whichever workspace happened to be in
# front. `app-route.sh` has always reloaded both; editing the file by hand, the
# path README documents, did not.
#
# Neither reload is a rendering failure: the file is already written, and a
# machine where AeroSpace is not running is a machine that will read it at
# launch.
if [ "$CONFIG_PATH" = "$HOME/.aerospace.toml" ] && command -v aerospace >/dev/null 2>&1; then
    if aerospace reload-config --dry-run --no-gui; then
        aerospace reload-config >/dev/null 2>&1 || true
    else
        printf 'AeroSpace did not accept the rendered config, or is not running.\n' >&2
    fi
fi
if [ "$CONFIG_PATH" = "$HOME/.aerospace.toml" ] &&
    [ -f "$HOME/.hammerspoon/init.lua" ] && command -v hs >/dev/null 2>&1; then
    hs -c 'hs.reload()' >/dev/null 2>&1 ||
        printf 'Hammerspoon did not reload; its route policies are still the ones it started with.\n' >&2
fi
