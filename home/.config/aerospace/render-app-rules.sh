#!/usr/bin/env bash
set -euo pipefail

# Renders the app placement and floating rules in ~/.aerospace.toml from
# app-defaults.sh, which is where they are actually maintained.
#
# Usage: render-app-rules.sh [path-to-aerospace.toml]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/write-guard.sh"
stdout_only=0
if [ "${1:-}" = --stdout ]; then stdout_only=1; shift; fi
CONFIG_PATH="${1:-$HOME/.aerospace.toml}"
RULES_FILE=""
OUTPUT_FILE=""

cleanup() {
    rm -f "$RULES_FILE" "$OUTPUT_FILE"
    ai_first_write_lock_release
}
trap cleanup EXIT
RULES_FILE="$(mktemp "${TMPDIR:-/tmp}/ai-first-render-rules.XXXXXX")"
OUTPUT_FILE="$(mktemp "${TMPDIR:-/tmp}/ai-first-render-output.XXXXXX")"

if [ "$stdout_only" -eq 0 ]; then
    ai_first_write_path_check "$CONFIG_PATH"
    ai_first_write_lock_acquire
    original="$(ai_first_file_state "$CONFIG_PATH")"
fi

if ! awk '
    /^# Application placement and floating rules\./ { begin++; start=NR }
    /^\[mode\.main\.binding\]/ { end++; finish=NR }
    END { exit !(begin == 1 && end == 1 && start < finish) }
' "$CONFIG_PATH"; then
    printf 'Missing or ambiguous app-rule markers in %s; no replacement.\n' "$CONFIG_PATH" >&2
    exit 65
fi
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

python3 -B "$SCRIPT_DIR/lib/validate-toml.py" "$OUTPUT_FILE"

if [ "$stdout_only" -eq 1 ]; then
    cat "$OUTPUT_FILE"
    exit 0
fi

if cmp -s "$OUTPUT_FILE" "$CONFIG_PATH"; then
    printf 'Unchanged: %s already matches app-defaults.sh\n' "$CONFIG_PATH"
    exit 0
fi

ai_first_replace_file "$OUTPUT_FILE" "$CONFIG_PATH" render-app-rules "$original"
printf 'To reload the current desktop explicitly: %s/activate.sh --apply\n' "$SCRIPT_DIR"
