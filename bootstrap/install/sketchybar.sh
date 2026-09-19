#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

SBARLUA_REPO="${SBARLUA_REPO:-https://github.com/FelixKratz/SbarLua.git}"
SBARLUA_REF="${SBARLUA_REF:-dba9cc421b868c918d5c23c408544a28aadf2f2f}"
SBARLUA_CACHE_DIR="${SBARLUA_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/Library/Caches}/dotfiles/SbarLua-$SBARLUA_REF}"
SBARLUA_INSTALL_DIR="${SBARLUA_INSTALL_DIR:-$HOME/.local/share/sketchybar_lua}"

ensure_parent_dir "$HOME/.config/sketchybar"
mkdir -p "$HOME/Library/Caches/sketchybar"

echo "Installing Sketchybar"

# Install runtime dependencies and supporting packages.
ensure_brew_tap felixkratz/formulae
brew_install lua switchaudio-osx nowplaying-cli jq gh sketchybar

# Install font dependencies required by the bar.
brew_install_cask sf-symbols font-sf-mono font-sf-pro

# The app font now travels with .config/sketchybar/fonts and is registered only
# in SketchyBar's process. Existing system/user fonts are intentionally kept.

install_sbarlua() {
  local ref_file="$SBARLUA_INSTALL_DIR/.sbarlua-ref"

  if [[ -f "$SBARLUA_INSTALL_DIR/sketchybar.so" && -f "$ref_file" ]] && grep -Fx "$SBARLUA_REF" "$ref_file" >/dev/null 2>&1; then
    printf 'SbarLua already installed at pinned ref: %s\n' "$SBARLUA_REF"
    return 0
  fi

  rm -rf "$SBARLUA_CACHE_DIR"
  git clone --filter=blob:none "$SBARLUA_REPO" "$SBARLUA_CACHE_DIR"
  git -C "$SBARLUA_CACHE_DIR" fetch --depth 1 origin "$SBARLUA_REF"
  git -C "$SBARLUA_CACHE_DIR" checkout --detach "$SBARLUA_REF"
  make -C "$SBARLUA_CACHE_DIR" install

  mkdir -p "$SBARLUA_INSTALL_DIR"
  printf '%s\n' "$SBARLUA_REF" >"$ref_file"
}

if should_install; then
  install_sbarlua
fi

echo "Setting up Sketchybar"
if should_deploy; then
  deploy_repo_path "$repo_root" "home/.config/sketchybar" "$HOME/.config/sketchybar" "$stamp"
fi

# `brew services` is a Homebrew command, so it belongs behind should_brew:
# --deploy-only and --no-brew both promise not to run any. It is also
# best-effort - the config is already on disk, and a machine whose brew refuses
# to restart one service (an untrusted tap, a service installed by hand) must
# not have that reported as the desktop profile failing.
if should_brew; then
  echo "Starting Sketchybar"
  if ! brew services restart sketchybar; then
    printf 'Could not restart the SketchyBar service. Start it yourself:\n  brew services restart sketchybar\n' >&2
  fi
else
  printf 'Skipping the SketchyBar service restart. Apply the deployed config with:\n  brew services restart sketchybar\n'
fi

cat <<'EOF'

SketchyBar theming:
- Fonts, sizes, geometry and colour roles live in ~/.config/sketchybar/theme.conf;
  the palette they refer to lives in ~/.config/sketchybar/colors.sh.
- Your edits to both survive re-running this installer. Use --force to take the
  shipped versions back.
- The space a window manager has to leave above the bar is derived from the bar
  geometry: ~/.config/sketchybar/lib/theme.sh get THEME_TOP_INSET

SketchyBar AI notification notes:
- Runtime attention state is stored in ~/Library/Caches/sketchybar, not in ~/.config/sketchybar.
- To let SketchyBar read macOS notification metadata, grant Full Disk Access to SketchyBar:
  System Settings -> Privacy & Security -> Full Disk Access -> add /opt/homebrew/bin/sketchybar
- macOS TCC permissions cannot be granted silently by this script.
EOF

echo "Finished setting up"
