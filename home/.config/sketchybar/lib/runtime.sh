#!/usr/bin/env bash
# Where the external binaries are, and how this config complains when one of
# them is missing.
#
# SketchyBar's scripts call three programs it does not own: `aerospace`,
# `hs` (Hammerspoon's CLI) and `sketchybar` itself. Every script used to hard
# code /opt/homebrew/bin/<name>, which is wrong twice over: an Intel Mac
# installs to /usr/local/bin, and a Mac with AeroSpace but no Hammerspoon has
# no `hs` at any path. A missing binary must degrade to a working bar with one
# line of explanation, never to a crash and never to silence - a bar that
# silently lands its workspace items on the wrong display looks exactly like a
# bar that is working.
#
# This file is a library: it defines functions and runs nothing on source, so
# it is safe under `set -euo pipefail` and safe to source more than once.
# It also forks no subprocesses - `command -v` is a shell builtin - because
# these functions run on SketchyBar's event callbacks.

# Resolves a program to an absolute path, or prints nothing.
#
#   $1  value of the caller's override variable, may be empty
#   $2  program name
#
# An override that names a program which is not there is still an answer: the
# caller asked for that path, and the emptiness below is what tells it the
# program is missing.
sketchybar_runtime_bin() {
  local override="${1:-}"
  local name="${2:-}"
  local candidate found

  if [ -n "$override" ]; then
    case "$override" in
      */*)
        [ -x "$override" ] && printf '%s\n' "$override"
        return 0
        ;;
      *)
        name="$override"
        ;;
    esac
  fi

  [ -n "$name" ] || return 0

  found="$(command -v "$name" 2>/dev/null || true)"
  if [ -n "$found" ] && [ -x "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi

  for candidate in "/opt/homebrew/bin/$name" "/usr/local/bin/$name"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
}

# True when the resolved path is something we can run.
sketchybar_runtime_has() {
  [ -n "${1:-}" ] && [ -x "$1" ]
}

# One warning per topic per process. SketchyBar re-runs these scripts on every
# event, and `items/spaces.sh` alone asks for three display ids, so an
# unguarded warning would fill the SketchyBar log rather than inform anyone.
sketchybar_warn_once() {
  local key="${1:-warn}"
  local guard guard_value

  shift || true

  # bash 3.2 has no associative arrays, so the guard is a variable name.
  # Pattern substitution rather than tr: this runs on an event callback.
  guard="_SKETCHYBAR_WARNED_${key//[!A-Za-z0-9]/_}"
  eval "guard_value=\${$guard:-}"
  if [ -n "${guard_value:-}" ]; then
    return 0
  fi
  eval "$guard=1"

  printf 'sketchybar: %s\n' "$*" >&2
}
