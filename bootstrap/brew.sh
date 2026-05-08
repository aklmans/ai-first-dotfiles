#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

usage() {
  cat <<'EOF'
Usage: ./bootstrap/brew.sh [profile...]

Profiles:
  base       baseline CLI tools and language toolchains (default)
  infra      local services and infrastructure CLIs
  desktop    window-management dependencies
  fonts      fonts required by tracked terminal and shell configs
  apps       optional GUI apps used on this machine
  quicklook  optional Finder preview plugins
  all        install every profile above
EOF
}

install_base() {
  ensure_brew_tap nao1215/tap

  # Base utilities required by the rest of the setup.
  brew_install mas coreutils gnu-sed

  # Everyday CLI tools and shell-facing utilities.
  brew_install ast-grep bat bottom chafa fd fzf gdu gh git-delta nao1215/tap/gup jq lazydocker lazygit neovim starship ripgrep tree trash yazi zoxide

  # Writing, media, and OCR helpers used by tracked workflows.
  brew_install hugo pandoc ffmpeg imagemagick summarize tesseract tesseract-lang

  # Language runtimes, developer toolchains, and update orchestration.
  brew_install composer go golangci-lint lua mise node protobuf topgrade uv
}

install_infra() {
  # Local services, container tooling, and infrastructure CLIs.
  brew_install dnsmasq docker kubernetes-cli mysql nginx ollama
}

install_desktop() {
  # Desktop status bar, borders, and audio helpers.
  ensure_brew_tap felixkratz/formulae
  ensure_brew_tap nikitabobko/tap
  brew_install felixkratz/formulae/borders felixkratz/formulae/sketchybar nowplaying-cli switchaudio-osx
  brew_install_cask nikitabobko/tap/aerospace hammerspoon bettertouchtool
}

install_fonts() {
  # Fonts required by tracked terminal and shell configs.
  brew_install_cask sf-symbols font-caskaydia-cove-nerd-font font-fantasque-sans-mono-nerd-font font-hack-nerd-font font-jetbrains-mono-nerd-font font-maple-mono
}

install_apps() {
  # Explicit tap dependency for the locally managed cc-switch cask.
  ensure_brew_tap farion1231/ccswitch
  ensure_brew_tap steipete/tap
  ensure_brew_tap tw93/tap

  # Optional terminal, utility, and desktop apps currently installed on this machine.
  brew_install tw93/tap/kakuku
  brew_install_cask adguard alt-tab karabiner-elements logi-options+ miaoyan ogdesign-eagle raycast

  # Optional AI, developer, and workflow GUI tools currently installed on this machine.
  brew_install_cask apifox cc-switch chatgpt claude claude-code codex steipete/tap/codexbar cursor openclaw postman visual-studio-code

  # Optional browser, writing, and communication apps currently installed on this machine.
  brew_install_cask arc google-chrome obsidian wechat
}

install_quicklook() {
  # Optional QuickLook extras for local Finder previews.
  brew_install_cask qlmarkdown quicklook-video syntax-highlight
  if [[ -d "$HOME/Library/QuickLook" ]]; then
    if xattr -r -p com.apple.quarantine "$HOME/Library/QuickLook" >/dev/null 2>&1; then
      xattr -r -d com.apple.quarantine "$HOME/Library/QuickLook"
    fi
  fi
}

install_all() {
  install_base
  install_infra
  install_desktop
  install_fonts
  install_apps
  install_quicklook
}

profile_args=("$@")
if [[ "${#profile_args[@]}" -eq 0 ]]; then
  profile_args=(base)
fi

for profile in "${profile_args[@]}"; do
  case "$profile" in
    -h|--help|help)
      usage
      exit 0
      ;;
    base)
      install_base
      ;;
    infra)
      install_infra
      ;;
    desktop)
      install_desktop
      ;;
    fonts)
      install_fonts
      ;;
    apps)
      install_apps
      ;;
    quicklook)
      install_quicklook
      ;;
    all)
      install_all
      ;;
    *)
      printf 'unknown brew profile: %s\n\n' "$profile" >&2
      usage >&2
      exit 1
      ;;
  esac
done
