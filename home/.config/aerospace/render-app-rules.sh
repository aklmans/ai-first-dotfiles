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

# A dry run is a courtesy check on a file that has already been written, and
# AeroSpace not running is not a rendering failure.
if [ "$CONFIG_PATH" = "$HOME/.aerospace.toml" ] && command -v aerospace >/dev/null 2>&1; then
    if ! aerospace reload-config --dry-run --no-gui; then
        printf 'AeroSpace did not accept the rendered config, or is not running.\n' >&2
    fi
fi
