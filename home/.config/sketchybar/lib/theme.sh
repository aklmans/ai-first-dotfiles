#!/usr/bin/env bash
# Resolves theme.conf into the variables the bar scripts actually use.
#
# colors.sh has always held the palette, but nothing held the rest: the font
# family lived in sketchybarrc while six font strings were spelled out again in
# plugins/ai_app_notifications.sh, the pill geometry was copy-pasted into four
# item files, `$BORDER_WIDTH` was referenced by four of them and defined by
# none, and the height the window manager has to reserve above the bar was one
# magic number hand-aligned across AeroSpace's config, Hammerspoon's recording
# layout and a test - arrived at from bar measurements that live here.
#
# Order of resolution, last one wins:
#   1. colors.sh          the palette
#   2. theme.conf         the user's edits
#   3. the environment    one-off runs and tests
#
# This file is a library. It defines functions, loads once, and forks no
# subprocesses, because plugins source it on SketchyBar's event callbacks.

# String surgery rather than `dirname` in a subshell: this file is sourced by
# plugins that SketchyBar re-runs on every event.
SKETCHYBAR_THEME_LIB_DIR="${BASH_SOURCE[0]%/*}"
[ "$SKETCHYBAR_THEME_LIB_DIR" != "${BASH_SOURCE[0]}" ] || SKETCHYBAR_THEME_LIB_DIR="."
SKETCHYBAR_THEME_CONFIG_DIR="${SKETCHYBAR_THEME_CONFIG_DIR:-$SKETCHYBAR_THEME_LIB_DIR/..}"

# A role is either a palette variable name or a literal colour. Names keep
# theme.conf free of shell expansion so Hammerspoon and Python can read it too.
#
# Assigns rather than prints: resolving twelve roles through command
# substitution would fork twelve times per event callback.
#
# The name lookup used to build `${<value>:-}` as a string and hand it back to
# the shell to run. That is not a palette lookup, it is a general expansion
# over whatever theme.conf said, re-run on every SketchyBar event: a role
# written as `x:-$(...)}` closed the brace and the command substitution ran.
# `${!value}` is the same lookup with no second parse, and `printf -v` assigns
# without one either, so the file stays data.
#
# The behaviour on the way in is unchanged: a literal 0x colour passes through
# unvalidated, and a name that resolves to nothing - unset, empty, or not a
# variable name at all - degrades silently to the shipped fallback, because a
# misspelt palette entry is a typo in a config file, not a reason to take the
# bar down.
sketchybar_theme_set_color() {
  local target="$1"
  local value="${2:-}"
  local fallback="${3:-}"
  local resolved

  case "$value" in
    0x*)
      printf -v "$target" '%s' "$value"
      return 0
      ;;
    # Empty, or not a variable name, so there is nothing to look up. Screened
    # here rather than inside ${!value}, where a bare "!" or "@" expands to a
    # special parameter and can abort a `set -u` plugin mid-repaint.
    ''|*[!A-Za-z0-9_]*|[0-9]*)
      printf -v "$target" '%s' "$fallback"
      return 0
      ;;
  esac

  resolved="${!value:-}"
  if [ -n "$resolved" ]; then
    printf -v "$target" '%s' "$resolved"
  else
    printf -v "$target" '%s' "$fallback"
  fi
}

SKETCHYBAR_THEME_CONF_WARNED=""
sketchybar_theme_conf_warn() {
  local file="$1"

  case " $SKETCHYBAR_THEME_CONF_WARNED " in
    *" $file "*) return 0 ;;
  esac
  SKETCHYBAR_THEME_CONF_WARNED="${SKETCHYBAR_THEME_CONF_WARNED:+$SKETCHYBAR_THEME_CONF_WARNED }$file"
  printf 'sketchybar: %s holds shell beyond KEY="value", so it is being executed rather than read as data; see the comments at the top of the shipped file for the format\n' \
    "$file" >&2
}

# Reads theme.conf without executing it.
#
# It used to be sourced, next to colors.sh, and it is sourced by the bar's
# config plus six item and plugin scripts - so a `$(...)` written into a theme
# value ran on every repaint. displays.conf and workspaces.conf were made data
# for the same reason; this is the third of the three files the README tells
# people to edit.
#
# colors.sh deliberately stays a script: its entries are unquoted and reference
# each other, so there is nothing to parse. The two files are not the same kind
# of thing and the header of each now says which it is.
#
# Every key here is SKETCHYBAR_-prefixed, so the prefix is the whitelist rather
# than a list of thirty-five names that would go stale the first time one is
# added. Values are assigned as they are read: a file that turns out to be
# unparseable falls back to being sourced, and sourcing re-assigns everything
# this loop had already set from the same lines, so there is nothing to undo.
sketchybar_theme_read_conf() {
  local file="$1"
  local line key raw
  local blank_re='^[[:space:]]*(#.*)?$'
  local assignment_re='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$'
  # Double quotes, single quotes, or a bare token, each with an optional
  # trailing comment. Same grammar as the AeroSpace conf reader, so the two
  # files people edit behave the same way.
  local dq_re='^"([^"]*)"[[:space:]]*(#.*)?$'
  local sq_re="^'([^']*)'[[:space:]]*(#.*)?\$"
  local bare_re='^([A-Za-z0-9_.:/+-]*)[[:space:]]*(#.*)?$'

  [ -r "$file" ] || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ $blank_re ]]; then
      continue
    fi
    if ! [[ "$line" =~ $assignment_re ]]; then
      sketchybar_theme_conf_warn "$file"
      # shellcheck source=/dev/null
      . "$file"
      return 0
    fi
    key="${BASH_REMATCH[1]}"
    raw="${BASH_REMATCH[2]}"

    if [[ "$raw" =~ $dq_re ]] || [[ "$raw" =~ $sq_re ]] || [[ "$raw" =~ $bare_re ]]; then
      # A `$(...)` inside a quoted value is not a reason to fall back. It is
      # the thing this parser exists to stop, and it is stopped by being
      # assigned literally.
      case "$key" in
        SKETCHYBAR_*) printf -v "$key" '%s' "${BASH_REMATCH[1]}" ;;
      esac
      continue
    fi

    sketchybar_theme_conf_warn "$file"
    # shellcheck source=/dev/null
    . "$file"
    return 0
  done <"$file"
}

sketchybar_theme_load() {
  local config_dir="${1:-$SKETCHYBAR_THEME_CONFIG_DIR}"
  local env_workspaces

  [ "${SKETCHYBAR_THEME_LOADED:-0}" != "1" ] || return 0

  # The environment outranks the file, so remember what it said before the
  # file overwrites it.
  env_workspaces="${SKETCHYBAR_WORKSPACES:-}"

  if [ -r "$config_dir/colors.sh" ]; then
    # shellcheck source=/dev/null
    . "$config_dir/colors.sh"
  fi

  sketchybar_theme_read_conf "$config_dir/theme.conf"

  # A preset is a set of overrides on top of theme.conf, not a replacement for
  # it: it wins for the keys it declares and leaves everything else alone. That
  # way "make the bar readable on a stream" is one line rather than twenty
  # edits, and switching back is deleting that line rather than restoring a
  # file from a backup.
  #
  # The name goes through the same whitelist as every other value this repo
  # turns into a path. It arrives from a file the user edits, and
  # "../../../etc/something" is a config typo away from being a file read.
  if [ -n "${SKETCHYBAR_THEME_PRESET:-}" ]; then
    case "$SKETCHYBAR_THEME_PRESET" in
      *[!A-Za-z0-9_-]*)
        printf 'sketchybar: theme preset %s is not a plain name, so it is being ignored\n' \
          "$SKETCHYBAR_THEME_PRESET" >&2
        ;;
      *)
        if [ -r "$config_dir/theme-presets/$SKETCHYBAR_THEME_PRESET.conf" ]; then
          sketchybar_theme_read_conf "$config_dir/theme-presets/$SKETCHYBAR_THEME_PRESET.conf"
        else
          printf 'sketchybar: no theme preset named %s in %s/theme-presets\n' \
            "$SKETCHYBAR_THEME_PRESET" "$config_dir" >&2
        fi
        ;;
    esac
  fi

  [ -z "$env_workspaces" ] || SKETCHYBAR_WORKSPACES="$env_workspaces"

  THEME_FONT="${SKETCHYBAR_FONT_FAMILY:-SF Pro}"
  THEME_FONT_APP="${SKETCHYBAR_FONT_APP:-sketchybar-app-font}"

  THEME_FONT_SIZE_ICON="${SKETCHYBAR_FONT_SIZE_ICON:-14.0}"
  THEME_FONT_SIZE_LABEL="${SKETCHYBAR_FONT_SIZE_LABEL:-13.0}"
  THEME_FONT_SIZE_APP_ICON="${SKETCHYBAR_FONT_SIZE_APP_ICON:-16.0}"
  THEME_FONT_SIZE_BADGE="${SKETCHYBAR_FONT_SIZE_BADGE:-14.0}"
  THEME_FONT_SIZE_BADGE_ICON="${SKETCHYBAR_FONT_SIZE_BADGE_ICON:-13.5}"
  THEME_FONT_SIZE_POPUP="${SKETCHYBAR_FONT_SIZE_POPUP:-12.0}"

  # Ready-to-use font strings, so no caller spells out a family again.
  THEME_FONT_ICON="$THEME_FONT:Bold:$THEME_FONT_SIZE_ICON"
  THEME_FONT_LABEL="$THEME_FONT:Semibold:$THEME_FONT_SIZE_LABEL"
  THEME_FONT_TITLE="$THEME_FONT:Black:$THEME_FONT_SIZE_ICON"
  THEME_FONT_HEAVY="$THEME_FONT:Heavy:$THEME_FONT_SIZE_APP_ICON"
  THEME_FONT_APP_ICON="$THEME_FONT_APP:Regular:$THEME_FONT_SIZE_APP_ICON"
  THEME_FONT_BADGE="$THEME_FONT:Semibold:$THEME_FONT_SIZE_BADGE"
  THEME_FONT_BADGE_ICON="$THEME_FONT:Semibold:$THEME_FONT_SIZE_BADGE_ICON"
  THEME_FONT_BADGE_APP_ICON="$THEME_FONT_APP:Regular:15.0"
  THEME_FONT_POPUP="$THEME_FONT:Semibold:$THEME_FONT_SIZE_POPUP"

  THEME_BAR_HEIGHT="${SKETCHYBAR_BAR_HEIGHT:-40}"
  THEME_BAR_Y_OFFSET="${SKETCHYBAR_BAR_Y_OFFSET:-35}"
  THEME_BAR_MARGIN="${SKETCHYBAR_BAR_MARGIN:-20}"
  THEME_BAR_BORDER_WIDTH="${SKETCHYBAR_BAR_BORDER_WIDTH:-2}"
  THEME_BAR_CORNER_RADIUS="${SKETCHYBAR_BAR_CORNER_RADIUS:-15}"
  THEME_BAR_PADDING="${SKETCHYBAR_BAR_PADDING:-10}"
  THEME_BAR_NOTCH_WIDTH="${SKETCHYBAR_BAR_NOTCH_WIDTH:-200}"

  THEME_ITEM_PADDING="${SKETCHYBAR_ITEM_PADDING:-3}"
  THEME_ITEM_HEIGHT="${SKETCHYBAR_ITEM_HEIGHT:-26}"
  THEME_ITEM_CORNER_RADIUS="${SKETCHYBAR_ITEM_CORNER_RADIUS:-15}"
  THEME_ITEM_BORDER_WIDTH="${SKETCHYBAR_ITEM_BORDER_WIDTH:-2}"
  THEME_PILL_CORNER_RADIUS="${SKETCHYBAR_PILL_CORNER_RADIUS:-15}"

  # The number AeroSpace and Hammerspoon have to agree with. Derived rather
  # than written down, so raising the bar cannot leave a strip of windows
  # underneath it.
  THEME_TOP_INSET="${SKETCHYBAR_BAR_TOP_INSET:-}"
  if [ -z "$THEME_TOP_INSET" ]; then
    THEME_TOP_INSET=$((THEME_BAR_HEIGHT + THEME_BAR_Y_OFFSET + THEME_BAR_MARGIN))
  fi
  THEME_TOP_INSET_COMPACT="${SKETCHYBAR_BAR_TOP_INSET_COMPACT:-8}"

  # Depth. Off by default because a shadow under a bar that sits 35px down the
  # wallpaper is decoration nobody asked for, and blur costs a repaint on every
  # event. A stream is the case where they earn their keep: on video the bar
  # otherwise sits flat against whatever is behind it.
  THEME_BAR_SHADOW="${SKETCHYBAR_BAR_SHADOW:-off}"
  THEME_BAR_BLUR="${SKETCHYBAR_BAR_BLUR:-0}"
  THEME_ITEM_SHADOW="${SKETCHYBAR_ITEM_SHADOW:-off}"

  sketchybar_theme_set_color THEME_ACCENT_BAR_BORDER "${SKETCHYBAR_ACCENT_BAR_BORDER:-BLUE}" "${BLUE:-}"
  sketchybar_theme_set_color THEME_ACCENT_CLOCK "${SKETCHYBAR_ACCENT_CLOCK:-MAGENTA}" "${MAGENTA:-}"
  sketchybar_theme_set_color THEME_ACCENT_CALENDAR "${SKETCHYBAR_ACCENT_CALENDAR:-BLUE}" "${BLUE:-}"
  sketchybar_theme_set_color THEME_ACCENT_BATTERY "${SKETCHYBAR_ACCENT_BATTERY:-CYAN}" "${CYAN:-}"
  sketchybar_theme_set_color THEME_ACCENT_VOLUME "${SKETCHYBAR_ACCENT_VOLUME:-GREEN}" "${GREEN:-}"
  sketchybar_theme_set_color THEME_ACCENT_FRONT_APP "${SKETCHYBAR_ACCENT_FRONT_APP:-BLUE}" "${BLUE:-}"
  sketchybar_theme_set_color THEME_ACCENT_WORKSPACE_ACTIVE "${SKETCHYBAR_ACCENT_WORKSPACE_ACTIVE:-BLUE}" "${BLUE:-}"
  sketchybar_theme_set_color THEME_ACCENT_WORKSPACE_IDLE "${SKETCHYBAR_ACCENT_WORKSPACE_IDLE:-GREY}" "${GREY:-}"
  sketchybar_theme_set_color THEME_ACCENT_WORKSPACE_ADD "${SKETCHYBAR_ACCENT_WORKSPACE_ADD:-ORANGE}" "${ORANGE:-}"
  sketchybar_theme_set_color THEME_ACCENT_ATTENTION "${SKETCHYBAR_ACCENT_ATTENTION:-BLUE}" "${BLUE:-}"
  sketchybar_theme_set_color THEME_ACCENT_MUTED "${SKETCHYBAR_ACCENT_MUTED:-GREY}" "${GREY:-}"
  sketchybar_theme_set_color THEME_ACCENT_ON_ACCENT "${SKETCHYBAR_ACCENT_ON_ACCENT:-WHITE}" "${WHITE:-}"

  # Four item files reference $BORDER_WIDTH and nothing ever defined it, so
  # every right-hand pill has been drawing a zero-width border. Keeping the
  # name means those files stay readable while the value finally exists.
  BORDER_WIDTH="$THEME_ITEM_BORDER_WIDTH"

  export THEME_FONT THEME_FONT_APP
  export THEME_FONT_SIZE_ICON THEME_FONT_SIZE_LABEL THEME_FONT_SIZE_APP_ICON
  export THEME_FONT_SIZE_BADGE THEME_FONT_SIZE_BADGE_ICON THEME_FONT_SIZE_POPUP
  export THEME_FONT_ICON THEME_FONT_LABEL THEME_FONT_TITLE THEME_FONT_HEAVY
  export THEME_FONT_APP_ICON THEME_FONT_BADGE THEME_FONT_BADGE_ICON
  export THEME_FONT_BADGE_APP_ICON THEME_FONT_POPUP
  export THEME_BAR_HEIGHT THEME_BAR_Y_OFFSET THEME_BAR_MARGIN
  export THEME_BAR_BORDER_WIDTH THEME_BAR_CORNER_RADIUS THEME_BAR_PADDING
  export THEME_BAR_NOTCH_WIDTH
  export THEME_ITEM_PADDING THEME_ITEM_HEIGHT THEME_ITEM_CORNER_RADIUS
  export THEME_ITEM_BORDER_WIDTH THEME_PILL_CORNER_RADIUS BORDER_WIDTH
  export THEME_BAR_SHADOW THEME_BAR_BLUR THEME_ITEM_SHADOW
  export THEME_TOP_INSET THEME_TOP_INSET_COMPACT
  export THEME_ACCENT_BAR_BORDER THEME_ACCENT_CLOCK THEME_ACCENT_CALENDAR
  export THEME_ACCENT_BATTERY THEME_ACCENT_VOLUME THEME_ACCENT_FRONT_APP
  export THEME_ACCENT_WORKSPACE_ACTIVE THEME_ACCENT_WORKSPACE_IDLE
  export THEME_ACCENT_WORKSPACE_ADD THEME_ACCENT_ATTENTION THEME_ACCENT_MUTED
  export THEME_ACCENT_ON_ACCENT

  SKETCHYBAR_THEME_LOADED=1
}

sketchybar_theme_load

# Executed rather than sourced, this prints resolved values. AeroSpace's gap
# rewrite and anything else outside bash can ask for the top inset here instead
# of writing the number down a second time:
#
#     ~/.config/sketchybar/lib/theme.sh get THEME_TOP_INSET
#
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-print}" in
    get)
      # argv[2] used to be spliced into a string the shell then re-parsed, so
      # `theme.sh get 'x};id;#'` ran whatever the caller passed. Same lookup,
      # no second parse: anything that is not a variable name resolves to
      # nothing, which is what an unset name has always printed.
      sketchybar_theme_get_name="${2:?missing variable name}"
      case "$sketchybar_theme_get_name" in
        *[!A-Za-z0-9_]*|[0-9]*) printf '\n' ;;
        *) printf '%s\n' "${!sketchybar_theme_get_name:-}" ;;
      esac
      ;;
    print)
      set | /usr/bin/grep '^THEME_' || true
      ;;
    *)
      printf 'usage: theme.sh [print|get <NAME>]\n' >&2
      exit 64
      ;;
  esac
fi
