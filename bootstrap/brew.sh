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
  apps       only apps in your private manifest (empty if none is configured)
  quicklook  optional Finder preview plugins
  all        install every profile above

Options:
  --plan     Print every tap, formula and cask; run no Homebrew command.
  --apps-manifest FILE  Private apps list; never evaluated as shell/Ruby.
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

  # Mobile and native build helpers, plus duti for setting default applications
  # from the shell.
  brew_install cocoapods duti watchman
}

install_infra() {
  # Local services, container tooling, and infrastructure CLIs.
  brew_install dnsmasq docker kubernetes-cli mysql nginx ollama
}

install_desktop() {
  # Desktop status bar, borders, and audio helpers.
  # BetterTouchTool is deliberately not here: it is paid after trial. Select
  # `setup.sh gestures`/`extras` or add it to your private apps manifest.
  ensure_brew_tap felixkratz/formulae
  ensure_brew_tap nikitabobko/tap
  brew_install felixkratz/formulae/borders felixkratz/formulae/sketchybar nowplaying-cli switchaudio-osx
  brew_install_cask nikitabobko/tap/aerospace hammerspoon
}

install_fonts() {
  # Fonts required by tracked terminal and shell configs.
  brew_install_cask sf-symbols font-caskaydia-cove-nerd-font font-fantasque-sans-mono-nerd-font font-hack-nerd-font font-jetbrains-mono-nerd-font font-maple-mono
}

install_apps() {
  local kind token extra
  if [[ ! -f "$apps_manifest" ]]; then
    printf 'No private apps manifest: %s. No optional apps selected.\n' "$apps_manifest"
    return 0
  fi
  while read -r kind token extra || [[ -n "${kind:-}" ]]; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    case "$kind" in
      tap) ensure_brew_tap "$token" ;;
      formula) brew_install "$token" ;;
      cask) brew_install_cask "$token" ;;
    esac
  done <"$apps_manifest"
}

validate_apps_manifest() {
  local kind token extra
  if [[ ! -f "$apps_manifest" ]]; then
    [[ "$apps_manifest_explicit" == 0 ]] && return 0
    printf 'Apps manifest is missing or not a regular file: %s\n' "$apps_manifest" >&2
    return 64
  fi
  # Validate the whole file before any package action, including base/all.
  while read -r kind token extra || [[ -n "${kind:-}" ]]; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    case "$kind" in tap|formula|cask) ;; *) return 64 ;; esac
    [[ -z "$extra" || "$extra" == \#* ]] || return 64
    [[ "$token" =~ ^[A-Za-z0-9][A-Za-z0-9@+._/-]*$ ]] || return 64
    case "/$token/" in */../*|*/./*|*//*) return 64 ;; esac
    if [[ "$kind" == tap ]]; then
      [[ "$token" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ]] || return 64
    fi
  done <"$apps_manifest"
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

profile_args=()
apps_manifest="${AI_FIRST_BREW_APPS_MANIFEST:-${XDG_CONFIG_HOME:-$HOME/.config}/ai-first/software/brew-apps.txt}"
apps_manifest_explicit=0
while [[ "$#" -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    --apps-manifest)
      [[ "$#" -ge 2 && -n "$2" ]] || { printf '%s requires a file path.\n' "$arg" >&2; exit 64; }
      apps_manifest="$2"
      apps_manifest_explicit=1
      shift
      ;;
    --plan)
      DOTFILES_BREW_PLAN=1
      ;;
    *)
      profile_args+=("$arg")
      ;;
  esac
  shift
done

if [[ "${#profile_args[@]}" -eq 0 ]]; then
  profile_args=(base)
fi

for profile in "${profile_args[@]}"; do
  case "$profile" in
    apps|all)
      validate_apps_manifest || { printf 'Invalid apps manifest; no packages changed. Expected: tap|formula|cask TOKEN.\n' >&2; exit 64; }
      ;;
  esac
done

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

# Once, after the whole plan, for the taps it turned out to involve. Per-item
# verdicts are printed beside the items that can carry one; this covers the ones
# named the way brew resolves them, where only brew knows which tap answers.
if [[ "${DOTFILES_BREW_PLAN:-0}" == "1" && "${DOTFILES_BREW_UNQUALIFIED:-0}" == "1" ]]; then
  # shellcheck disable=SC2086
  brew_plan_note_untrusted_taps $DOTFILES_BREW_TAPS
fi
