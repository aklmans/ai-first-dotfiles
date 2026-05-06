#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
repo_root="$(repo_root_dir)"

dry_run=0
no_brew=0
deploy_only=0
install_only=0

usage() {
  cat <<'EOF'
Usage: ./bootstrap/setup.sh [profile...] [options]

Profiles:
  all           Recommended bootstrap: packages, shell, desktop, ai, media
  packages      Homebrew packages required by the recommended setup
  packages-all  Every Homebrew profile in bootstrap/brew.sh
  gui-path      Make Homebrew tools visible to GUI-launched apps
  shell         zsh, Starship, Kaku, Warp, Yazi, IdeaVim
  sublime       Sublime Text Terminal package integration
  desktop       Karabiner, AeroSpace, SketchyBar, Borders, BTT, Hammerspoon
  ai            AI Workflow Router
  media         mpv
  app-store     App Store apps from manifests/app-store
  gbrain        Optional local GBrain setup
  deploy        Deploy all tracked config without package installation

Options:
  --no-brew       Skip Homebrew commands where possible.
  --deploy-only   Deploy config only.
  --install-only  Install packages/external dependencies only.
  --dry-run       Print commands without running them.
  -h, --help      Show this help.
EOF
}

run_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'

  if [[ "$dry_run" -eq 1 ]]; then
    return 0
  fi

  "$@"
}

module_flags() {
  if [[ "$deploy_only" -eq 1 ]]; then
    printf '%s\n' --deploy-only
    return 0
  fi

  if [[ "$install_only" -eq 1 ]]; then
    printf '%s\n' --install-only
  fi

  if [[ "$no_brew" -eq 1 ]]; then
    printf '%s\n' --no-brew
  fi
}

run_module() {
  local module="$1"
  shift || true

  local -a flags
  flags=()
  while IFS= read -r flag; do
    [[ -n "$flag" ]] && flags+=("$flag")
  done < <(module_flags)

  if [[ "${#flags[@]}" -gt 0 ]]; then
    run_cmd "$repo_root/bootstrap/install/$module.sh" "${flags[@]}" "$@"
  else
    run_cmd "$repo_root/bootstrap/install/$module.sh" "$@"
  fi
}

run_brew_profile() {
  local profiles=("$@")

  if [[ "$no_brew" -eq 1 || "$deploy_only" -eq 1 ]]; then
    printf 'Skipping Homebrew profile: %s\n' "${profiles[*]}"
    return 0
  fi

  run_cmd "$repo_root/bootstrap/brew.sh" "${profiles[@]}"
}

profile_packages() {
  run_brew_profile base desktop fonts
}

profile_packages_all() {
  run_brew_profile all
}

profile_gui_path() {
  run_module gui-path
}

profile_shell() {
  run_module zsh
  run_module starship
  run_module kaku
  run_module warp
  run_module yazi
  run_module ideavim
}

profile_sublime() {
  run_module sublime
}

profile_desktop() {
  run_module karabiner
  run_module aerospace
  run_module sketchybar
  run_module borders
  run_module bettertouchtool
  run_module hammerspoon
}

profile_ai() {
  run_module ai-router
}

profile_media() {
  run_module mpv
}

profile_app_store() {
  if [[ "$deploy_only" -eq 1 ]]; then
    printf 'Skipping App Store profile in deploy-only mode.\n'
    return 0
  fi
  run_cmd "$repo_root/bootstrap/app-store.sh"
}

profile_gbrain() {
  if [[ "$deploy_only" -eq 1 ]]; then
    printf 'Skipping GBrain profile in deploy-only mode.\n'
    return 0
  fi
  run_cmd "$repo_root/bootstrap/install/gbrain.sh"
}

profile_deploy() {
  local previous_deploy_only="$deploy_only"
  deploy_only=1
  profile_gui_path
  profile_shell
  profile_sublime
  profile_desktop
  profile_ai
  profile_media
  deploy_only="$previous_deploy_only"
}

profile_all() {
  profile_packages
  profile_gui_path
  profile_shell
  profile_sublime
  profile_desktop
  profile_ai
  profile_media
}

profiles=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-brew)
      no_brew=1
      ;;
    --deploy-only)
      deploy_only=1
      ;;
    --install-only)
      install_only=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      profiles+=("$1")
      ;;
  esac
  shift
done

if [[ "${#profiles[@]}" -eq 0 ]]; then
  profiles=(all)
fi

for profile in "${profiles[@]}"; do
  case "$profile" in
    all)
      profile_all
      ;;
    packages)
      profile_packages
      ;;
    packages-all)
      profile_packages_all
      ;;
    gui-path)
      profile_gui_path
      ;;
    shell)
      profile_shell
      ;;
    sublime)
      profile_sublime
      ;;
    desktop)
      profile_desktop
      ;;
    ai)
      profile_ai
      ;;
    media)
      profile_media
      ;;
    app-store)
      profile_app_store
      ;;
    gbrain)
      profile_gbrain
      ;;
    deploy)
      profile_deploy
      ;;
    *)
      printf 'Unknown setup profile: %s\n\n' "$profile" >&2
      usage >&2
      exit 1
      ;;
  esac
done
