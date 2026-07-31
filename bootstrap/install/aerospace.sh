#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

ensure_brew_tap nikitabobko/tap
brew_install_cask nikitabobko/tap/aerospace

if should_deploy; then
  deploy_repo_path "$repo_root" "home/.aerospace.toml" "$HOME/.aerospace.toml" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/aerospace" "$HOME/.config/aerospace" "$stamp"

  # The shipped .aerospace.toml is generated from the shipped workspaces.conf
  # and displays.conf. Those two files are the ones a user edits, and the deploy
  # engine keeps their edits - but an update to the repo's .aerospace.toml
  # replaces the rendered result of those edits with the shipped default. So
  # render once here: on an unmodified config it changes nothing, and on a
  # customised one it puts the user's workspace count and monitor names back
  # without them having to remember to.
  #
  # Legacy installs may have hand-edited app rules in TOML, so they retain the
  # old layout-only render. A named ai-first preset owns the routing choice in
  # profile.conf; for those installs render the rule block too, including the
  # intentionally empty block used by the minimal preset.
  if [ -x "$HOME/.config/aerospace/render-layout.sh" ]; then
    render_status=0
    if [ -r "$HOME/.config/ai-first/profile.conf" ] && \
      grep -Eq '^AI_FIRST_APP_ROUTING=' "$HOME/.config/ai-first/profile.conf"; then
      "$HOME/.config/aerospace/render-layout.sh" "$HOME/.aerospace.toml" || render_status=$?
    else
      "$HOME/.config/aerospace/render-layout.sh" --no-app-rules "$HOME/.aerospace.toml" || render_status=$?
    fi
    if [ "$render_status" -ne 0 ]; then
      printf 'Could not re-render the workspace layout blocks of %s; the deployed config is unchanged.\n' \
        "$HOME/.aerospace.toml" >&2
    fi
  fi
fi

# Writing a global macOS default and launching an app are installation steps,
# not deployment steps. --deploy-only promises to write config and nothing else,
# so a user previewing this repo by deploying into a fresh checkout does not get
# a system setting changed and an app opened behind their back.
if should_install; then
  # Enable macOS native Ctrl+Cmd window dragging. Some apps need restart to pick it up.
  defaults write -g NSWindowShouldDragOnGesture -bool true

  if ! open -a AeroSpace 2>/dev/null; then
    printf 'AeroSpace is not installed yet; skipping its launch. Start it yourself once it is.\n'
  fi
fi

# Reloading is not an install step: it only makes the config that was just
# deployed take effect in an already running AeroSpace. If AeroSpace is not
# running, or rejects the config, say so rather than failing the whole run - the
# files are on disk either way and the running window manager is left alone.
if should_deploy && command -v aerospace >/dev/null 2>&1; then
  if aerospace reload-config --dry-run --no-gui; then
    aerospace reload-config || true
  else
    printf 'AeroSpace did not accept the deployed config (or is not running); its current config is unchanged.\n' >&2
  fi
fi
