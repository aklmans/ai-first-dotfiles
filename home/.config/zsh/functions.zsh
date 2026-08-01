# Shell functions.
#
# Each one is defined only when the thing it drives is installed, so a shell on
# a machine without SketchyBar or Yazi does not carry names that fail.
#
# `kill` is deliberately absent. This file used to redefine it so that a single
# non-numeric argument became `pkill -x`, which means `kill nginx` silently did
# something the manual page for `kill` does not describe - and on a shared or
# unfamiliar machine, shadowing a builtin that ends processes is the wrong place
# to be clever. Use `pkill` when you mean pkill.

# Toggle the SketchyBar zen/focus mode. Part of the `bar` module.
if [[ -x "$HOME/.config/sketchybar/plugins/zen.sh" ]]; then
  zen() {
    "$HOME/.config/sketchybar/plugins/zen.sh" "$@"
  }
fi

# Open Yazi and cd to wherever it was left. Part of the `shell` module.
if command -v yazi >/dev/null 2>&1; then
  yy() {
    # Yazi sets YAZI_LEVEL in the shell it spawns; without this guard `yy` from
    # inside Yazi's own shell would nest another one.
    if [[ -n "$YAZI_LEVEL" ]]; then
      exit
    fi

    local tmp cwd
    tmp="$(mktemp -t 'yazi-cwd.XXXXX')"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi
