#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

ensure_parent_dir "$HOME/.config/yazi"
mkdir -p "$HOME/.local/state"

echo "Installing Yazi: "
echo "Installing Dependencies"
brew_install yazi ffmpegthumbnailer unar jq mpv poppler fd ripgrep fzf zoxide font-symbols-only-nerd-font
brew_install bat exiftool tree glow imagemagick pandoc sqlite smali miller transmission-cli woff2 rich

echo "Setting up Yazi"
if should_deploy; then
  deploy_repo_path "$repo_root" "home/.config/yazi" "$HOME/.config/yazi" "$stamp"
fi

# Every plugin here is optional decoration for a file manager. None of them is
# worth ending a bootstrap run over, and this used to end it twice: once when
# `ya` was missing or too old to have a package command, and once for every
# plugin that was already installed or briefly unreachable. Warn and carry on.
yazi_package_warned=0

warn_yazi_packages_once() {
  local reason="$1"

  [[ "$yazi_package_warned" -eq 0 ]] || return 0
  yazi_package_warned=1
  printf 'Skipping the optional Yazi plugins: %s\n' "$reason" >&2
  printf 'Yazi itself is installed and configured; add them later with `ya pkg add <plugin>`.\n' >&2
}

add_yazi_package() {
  local package="$1"

  if ! command -v ya >/dev/null 2>&1; then
    warn_yazi_packages_once 'the `ya` command is not on PATH'
    return 0
  fi

  if ya pkg --help >/dev/null 2>&1; then
    ya pkg add "$package" || printf 'Could not add the Yazi plugin %s; continuing.\n' "$package" >&2
    return 0
  fi

  if ya pack --help >/dev/null 2>&1; then
    ya pack -a "$package" || printf 'Could not add the Yazi plugin %s; continuing.\n' "$package" >&2
    return 0
  fi

  warn_yazi_packages_once 'no supported Yazi package command found (expected `ya pkg` or legacy `ya pack`)'
  return 0
}

# Same reasoning as add_yazi_package: an optional third-party checkout that is
# unreachable, already there under another form, or behind a proxy must not end
# the run.
install_preview_plugin() {
  local target="$HOME/.config/yazi/plugins/preview.yazi"

  mkdir -p "$(dirname "$target")"

  if [[ -d "$target/.git" ]]; then
    git -C "$target" pull --ff-only ||
      printf 'Could not update the Yazi preview plugin at %s; keeping the checkout as it is.\n' "$target" >&2
    return 0
  fi

  if [[ -e "$target" ]]; then
    printf 'Yazi preview plugin path exists but is not a git checkout; leaving it alone: %s\n' "$target" >&2
    return 0
  fi

  git clone https://github.com/Urie96/preview.yazi.git "$target" ||
    printf 'Could not clone the Yazi preview plugin; continuing without it.\n' >&2
}

if should_install; then
  # Intentional external plugin installs that fetch Yazi extensions from upstream.
  add_yazi_package AnirudhG07/rich-preview
  add_yazi_package dedukun/relative-motions
  add_yazi_package dedukun/bookmarks
  add_yazi_package Reledia/glow
  add_yazi_package Sonico98/exifaudio
  add_yazi_package ndtoan96/ouch
  add_yazi_package lpnh/fg
  add_yazi_package Rolv-Apneseth/bypass
  add_yazi_package Reledia/hexyl
  add_yazi_package kirasok/epub-preview
  add_yazi_package yazi-rs/plugins:max-preview
  add_yazi_package yazi-rs/plugins:chmod
  add_yazi_package yazi-rs/plugins:smart-filter
  add_yazi_package yazi-rs/plugins:full-border

  # Intentional external plugin checkout for a standalone preview extension.
  install_preview_plugin

  ya pkg install >/dev/null 2>&1 || true
fi

echo "Finished installing Yazi"
