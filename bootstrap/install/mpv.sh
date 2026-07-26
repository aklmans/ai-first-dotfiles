#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

# The formula, not the cask. bootstrap/install/yazi.sh already installs the mpv
# formula as a preview dependency, and Homebrew disables the mpv cask on
# 2026-09-01; having both in one `setup.sh all` run meant the deprecated cask
# fighting the formula over the same `mpv` binary.
brew_install mpv

install_osc_font() {
  should_brew || return 0
  if ! command -v brew >/dev/null 2>&1; then
    printf 'brew not found; skip optional font install for mpv OSC graphics.\n'
    return 0
  fi

  if brew list --cask --versions font-material-design-icons-webfont >/dev/null 2>&1; then
    return 0
  fi

  # Optional, best-effort: install public font used by ModernX icon glyphs.
  brew install --cask font-material-design-icons-webfont || \
    brew install --cask font-material-icons || true
}

if should_deploy; then
  deploy_repo_path "$repo_root" "home/.config/mpv" "$HOME/.config/mpv" "$stamp"
fi

install_osc_font
