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
