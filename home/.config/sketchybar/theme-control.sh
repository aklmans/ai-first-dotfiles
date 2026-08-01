#!/usr/bin/env bash
set -euo pipefail

# Switches the bar between the looks in theme-presets/, and puts everything that
# has to agree with the bar's size back in agreement.
#
# Usage:
#   theme-control.sh                 what is selected now, and what else there is
#   theme-control.sh <name>          select that preset
#   theme-control.sh off             go back to theme.conf on its own
#
# A preset only overrides the keys it declares, so switching never loses an edit
# made in theme.conf. This script owns exactly one line of that file.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
CONFIG_DIR="${SKETCHYBAR_CONFIG_DIR:-$SCRIPT_DIR}"
THEME_CONF="$CONFIG_DIR/theme.conf"
PRESET_DIR="$CONFIG_DIR/theme-presets"
KEY="SKETCHYBAR_THEME_PRESET"
SKETCHYBAR="${SKETCHYBAR_BIN:-$(command -v sketchybar || true)}"
AEROSPACE_TOGGLE="${AEROSPACE_TOGGLE:-$HOME/.config/aerospace/toggle-sketchybar-space.sh}"

current_preset() {
    [ -r "$THEME_CONF" ] || return 0
    /usr/bin/awk -F'"' -v key="$KEY" '
        $0 ~ "^[[:space:]]*" key "=" { value = $2 }
        END { print value }
    ' "$THEME_CONF"
}

available_presets() {
    local file
    [ -d "$PRESET_DIR" ] || return 0
    for file in "$PRESET_DIR"/*.conf; do
        [ -f "$file" ] || continue
        file="${file##*/}"
        printf '%s\n' "${file%.conf}"
    done
}

summary() {
    local current name
    current="$(current_preset)"

    printf 'Selected: %s\n' "${current:-none (theme.conf on its own)}"
    printf 'Available:\n'
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if [ "$name" = "$current" ]; then
            printf '  * %s\n' "$name"
        else
            printf '    %s\n' "$name"
        fi
    done <<EOF
$(available_presets)
EOF
    printf '\n%s <name>   select    %s off   back to theme.conf\n' \
        "${0##*/}" "${0##*/}"
}

# One line, in place, with the previous file kept. The whole point of a preset is
# that theme.conf stays the user's, so this rewrites the one key and copies every
# other byte through - including the comments above it.
select_preset() {
    local value="$1" backup candidate

    [ -w "$THEME_CONF" ] || {
        printf 'theme-control: cannot write %s\n' "$THEME_CONF" >&2
        return 1
    }

    candidate="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/theme-conf.XXXXXX")" || return 1
    /usr/bin/awk -v key="$KEY" -v value="$value" '
        $0 ~ "^[[:space:]]*" key "=" {
            printf "%s=\"%s\"\n", key, value
            found = 1
            next
        }
        { print }
        END {
            # An older deployed theme.conf predates the key entirely. Appending
            # is better than refusing: the alternative is telling someone to
            # hand-edit the file this command exists to avoid hand-editing.
            if (!found) { printf "\n%s=\"%s\"\n", key, value }
        }
    ' "$THEME_CONF" >"$candidate" || {
        rm -f "$candidate"
        return 1
    }

    backup="$THEME_CONF.bak-theme-control"
    cp "$THEME_CONF" "$backup" || {
        rm -f "$candidate"
        return 1
    }
    mv "$candidate" "$THEME_CONF"
    printf 'theme.conf: %s="%s" (previous file kept at %s)\n' "$KEY" "$value" "${backup##*/}"
}

# The bar's height is one of two numbers that have to match. The other is
# AeroSpace's outer.top gap, which lives in ~/.aerospace.toml and is written by
# toggle-sketchybar-space.sh from the same theme. `apply` re-runs whichever mode
# is currently saved, so the gap is recomputed without the bar being shown or
# hidden behind the user's back. Without this a taller preset puts every window
# under the bar.
apply_everywhere() {
    if [ -n "$SKETCHYBAR" ] && [ -x "$SKETCHYBAR" ]; then
        "$SKETCHYBAR" --reload >/dev/null 2>&1 ||
            printf 'theme-control: SketchyBar did not reload; it may not be running.\n' >&2
    else
        printf 'theme-control: no sketchybar on PATH, so nothing was reloaded.\n' >&2
    fi

    if [ -x "$AEROSPACE_TOGGLE" ]; then
        "$AEROSPACE_TOGGLE" apply >/dev/null 2>&1 ||
            printf 'theme-control: could not resync the AeroSpace top gap; run %s apply\n' \
                "$AEROSPACE_TOGGLE" >&2
    fi
}

case "${1:-}" in
    ''|list|-l|--list)
        summary
        ;;
    -h|--help|help)
        summary
        ;;
    off|none|default)
        select_preset ""
        apply_everywhere
        ;;
    *)
        case "$1" in
            *[!A-Za-z0-9_-]*)
                printf 'theme-control: %s is not a plain preset name\n' "$1" >&2
                exit 64
                ;;
        esac
        if [ ! -r "$PRESET_DIR/$1.conf" ]; then
            printf 'theme-control: no preset named %s\n\n' "$1" >&2
            summary >&2
            exit 64
        fi
        select_preset "$1"
        apply_everywhere
        ;;
esac
