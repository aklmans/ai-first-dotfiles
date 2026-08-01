#!/usr/bin/env bash
# Which workspaces get a chip on the bar.
#
# Two files used to answer this with the literal string "1 2 3 4 5 6 7 8 9 10
# 11 12 13": the item file that creates the chips and the plugin that repaints
# them. Anyone running a different number of workspaces got chips for
# workspaces that do not exist and no chip for the ones that do.
#
# The answer belongs to AeroSpace - the workspaces are its workspaces - so this
# asks ~/.config/aerospace/ for it. What it does not do is *depend* on
# AeroSpace being installed:
#
#   1. SKETCHYBAR_WORKSPACES, from the environment or theme.conf
#   2. ~/.config/aerospace/lib/layout.sh, the library that owns the list
#   3. ~/.config/aerospace/workspaces.conf, if the library is missing but the
#      data file is there - a partial install, or someone who copied the config
#      files without the scripts
#   4. `aerospace list-workspaces --all`, asking the running window manager
#   5. nothing, with one warning
#
# Step 5 is the honest answer for a Mac with SketchyBar and no AeroSpace: a
# workspace chip is an AeroSpace workspace indicator, and inventing five of
# them would be inventing workspaces. Every other item on the bar keeps working.
#
# Library: defines functions, runs nothing on source, safe under
# `set -euo pipefail` and safe to source twice.

SKETCHYBAR_WORKSPACES_LIB_DIR="${BASH_SOURCE[0]%/*}"
[ "$SKETCHYBAR_WORKSPACES_LIB_DIR" != "${BASH_SOURCE[0]}" ] || SKETCHYBAR_WORKSPACES_LIB_DIR="."

if [ -r "$SKETCHYBAR_WORKSPACES_LIB_DIR/runtime.sh" ]; then
  # shellcheck source=runtime.sh
  . "$SKETCHYBAR_WORKSPACES_LIB_DIR/runtime.sh"
fi

# Collapses whitespace so a list written across lines compares and iterates
# cleanly. Same contract as the AeroSpace library's normaliser.
sketchybar_workspaces_normalize() {
  local item first=1

  for item in ${1:-}; do
    if [ "$first" -eq 1 ]; then
      printf '%s' "$item"
      first=0
    else
      printf ' %s' "$item"
    fi
  done
  printf '\n'
}

# Reads the three role lists out of workspaces.conf without sourcing it, so a
# stray command in a config file cannot run inside a bar callback.
#
# The grammar is the one workspaces.conf documents and aerospace/lib/layout.sh
# parses: leading indent, spaces around the `=`, either quote or none, and an
# optional trailing comment. Three programs read that file - this one,
# layout.sh and Hammerspoon's screencast.lua - and a line one of them accepts
# and another silently skips is a workspace that exists on the bar and not in
# the window manager, which is worse than either answer alone.
sketchybar_workspaces_from_conf() {
  local conf="$1"
  local line key raw value main="" side="" stage=""
  local assignment_re='^[[:space:]]*(AEROSPACE_(MAIN|SIDE|STAGE)_WORKSPACES)[[:space:]]*=[[:space:]]*(.*)$'
  local dq_re='^"([^"]*)"[[:space:]]*(#.*)?$'
  local sq_re="^'([^']*)'[[:space:]]*(#.*)?\$"
  local bare_re='^([A-Za-z0-9_.:/+-]*)[[:space:]]*(#.*)?$'

  [ -r "$conf" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    if ! [[ "$line" =~ $assignment_re ]]; then
      continue
    fi
    key="${BASH_REMATCH[1]}"
    raw="${BASH_REMATCH[3]}"
    if [[ "$raw" =~ $dq_re ]] || [[ "$raw" =~ $sq_re ]] || [[ "$raw" =~ $bare_re ]]; then
      value="${BASH_REMATCH[1]}"
    else
      continue
    fi
    case "$key" in
      AEROSPACE_MAIN_WORKSPACES) main="$value" ;;
      AEROSPACE_SIDE_WORKSPACES) side="$value" ;;
      AEROSPACE_STAGE_WORKSPACES) stage="$value" ;;
    esac
  done <"$conf"

  value="$(sketchybar_workspaces_normalize "$main $side $stage")"
  [ -n "$value" ] || return 1
  printf '%s\n' "$value"
}

sketchybar_workspace_list() {
  local aerospace_config_dir="${AEROSPACE_CONFIG_DIR:-$HOME/.config/aerospace}"
  local resolved bin

  if [ -n "${SKETCHYBAR_WORKSPACES:-}" ]; then
    sketchybar_workspaces_normalize "$SKETCHYBAR_WORKSPACES"
    return 0
  fi

  # The library, when it is there. Only the workspace list is asked for:
  # aerospace_layout_resolve() shells out to `aerospace list-monitors`, which
  # has no business running on a repaint.
  if [ -r "$aerospace_config_dir/lib/layout.sh" ]; then
    # shellcheck source=/dev/null
    . "$aerospace_config_dir/lib/layout.sh"
    if type aerospace_layout_workspaces >/dev/null 2>&1; then
      resolved="$(aerospace_layout_workspaces)"
      if [ -n "$resolved" ]; then
        printf '%s\n' "$resolved"
        return 0
      fi
    fi
  fi

  if resolved="$(sketchybar_workspaces_from_conf "$aerospace_config_dir/workspaces.conf")"; then
    printf '%s\n' "$resolved"
    return 0
  fi

  if type sketchybar_runtime_bin >/dev/null 2>&1; then
    bin="$(sketchybar_runtime_bin "${AEROSPACE_BIN:-${AEROSPACE:-}}" aerospace)"
  else
    bin="${AEROSPACE_BIN:-${AEROSPACE:-}}"
  fi

  if [ -n "$bin" ] && [ -x "$bin" ]; then
    resolved="$(sketchybar_workspaces_normalize "$("$bin" list-workspaces --all 2>/dev/null || true)")"
    if [ -n "$resolved" ]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  if type sketchybar_warn_once >/dev/null 2>&1; then
    sketchybar_warn_once workspaces \
      "no workspace list found (looked at SKETCHYBAR_WORKSPACES, $aerospace_config_dir and the aerospace CLI); the bar will show no workspace items"
  else
    printf 'sketchybar: no workspace list found; the bar will show no workspace items\n' >&2
  fi

  printf '\n'
}

# Which display each workspace chip belongs on, as "<workspace> <display id>"
# per line.
#
# The chips carry a display id rather than `display=active`, because the whole
# point of them is that workspaces 7-12 live on the side monitor whether or not
# you are looking at it. That id is resolved once, when the bar is configured -
# so unplugging a monitor left every chip pointing at a display that is no
# longer there, and the only way back was `sketchybar --reload` by hand.
#
# Callers must have sourced display-resolver.sh, and should have re-run
# aerospace_layout_resolve first if the displays have just changed: both of the
# lookups below are answered from cached state.
sketchybar_workspace_display_bindings() {
  local sid role name main_display="" side_display="" stage_display=""

  # Arrangement id 1 always exists, so an unresolvable role puts its workspaces
  # on a real display instead of on display 2 or 3 of a laptop that has neither.
  _binding_display_for_role() {
    local want="$1" target="$2" resolved=""

    if type aerospace_layout_resolved_name >/dev/null 2>&1; then
      name="$(aerospace_layout_resolved_name "$want")"
    else
      name=""
    fi

    if [ -n "$name" ] && type sketchybar_display_id_for_monitor_var >/dev/null 2>&1; then
      sketchybar_display_id_for_monitor_var "$name" || true
      resolved="${SKETCHYBAR_DISPLAY_ID:-}"
    fi

    if [ -z "$resolved" ] && [ "$want" != "main" ]; then
      resolved="$main_display"
    fi

    printf -v "$target" '%s' "${resolved:-1}"
  }

  _binding_display_for_role main main_display
  _binding_display_for_role side side_display
  _binding_display_for_role stage stage_display

  for sid in $(sketchybar_workspace_list); do
    [ -n "$sid" ] || continue

    role=main
    if type aerospace_layout_role_for_workspace >/dev/null 2>&1; then
      role="$(aerospace_layout_role_for_workspace "$sid" 2>/dev/null || printf 'main')"
    fi

    case "$role" in
      side) printf '%s %s\n' "$sid" "$side_display" ;;
      stage) printf '%s %s\n' "$sid" "$stage_display" ;;
      *) printf '%s %s\n' "$sid" "$main_display" ;;
    esac
  done

  unset -f _binding_display_for_role
}
