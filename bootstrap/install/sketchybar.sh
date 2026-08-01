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
mkdir -p "$HOME/Library/Fonts"
mkdir -p "$HOME/Library/Caches/sketchybar"

echo "Installing Sketchybar"

# Install runtime dependencies and supporting packages.
ensure_brew_tap felixkratz/formulae
brew_install lua switchaudio-osx nowplaying-cli jq gh sketchybar

# Install font dependencies required by the bar.
brew_install_cask sf-symbols font-sf-mono font-sf-pro

# Downloads are written to a temporary file and only moved into place once they
# look like a font. Without --fail a proxy or captive portal answering with an
# HTML error page used to be saved as sketchybar-app-font.ttf, cached forever
# because the file now exists, and reported as a successful install.
install_sketchybar_app_font() {
  local target="$HOME/Library/Fonts/sketchybar-app-font.ttf"
  local url='https://github.com/aklmans/sketchybar-app-font/releases/download/v2.0.69/sketchybar-app-font.ttf'
  local temp magic

  if [[ -f "$target" ]]; then
    printf 'SketchyBar app font already installed: %s\n' "$target"
    return 0
  fi

  temp="$(mktemp "${TMPDIR:-/tmp}/sketchybar-app-font.XXXXXX")" || return 0

  # Intentional external asset fetch: this downloads the bar font from upstream.
  if ! curl --fail --location --silent --show-error --output "$temp" "$url"; then
    rm -f "$temp"
    printf 'Could not download the SketchyBar app font. App icons in the bar will be missing.\n' >&2
    printf 'Retry later, or fetch it yourself into %s:\n  %s\n' "$target" "$url" >&2
    return 0
  fi

  # A 200 response is not proof of a font: check the sfnt/ttcf signature before
  # this lands in ~/Library/Fonts, where a broken file would stay for good.
  magic="$(od -A n -t x1 -N 4 "$temp" 2>/dev/null | tr -d ' \n')"
  case "$magic" in
    00010000|74727565|4f54544f|74746366)
      ;;
    *)
      rm -f "$temp"
      printf 'The SketchyBar app font download was not a font (signature %s); discarded it.\n' "${magic:-empty}" >&2
      printf 'Nothing was installed. Fetch it yourself into %s:\n  %s\n' "$target" "$url" >&2
      return 0
      ;;
  esac

  mv "$temp" "$target"
  printf 'Installed SketchyBar app font: %s\n' "$target"
}

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
  install_sketchybar_app_font
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
