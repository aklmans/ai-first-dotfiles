#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
start_btt=0

args=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --start|--apply-preset)
      start_btt=1
      ;;
    *)
      args+=("$1")
      ;;
  esac
  shift
done

# Guarded expansion: bash 3.2 (the macOS system bash) treats "${args[@]}" as an
# unbound variable when the array is empty, which aborts the script under `set -u`.
parse_install_args ${args[@]+"${args[@]}"}

brew_install_cask bettertouchtool

if should_deploy; then
  deploy_repo_path "$repo_root" "home/.config/bettertouchtool" "$HOME/.config/bettertouchtool" "$stamp"

  if [[ "$start_btt" -eq 1 ]]; then
    "$HOME/.config/bettertouchtool/aerospace-gestures.sh"
  else
    printf 'BetterTouchTool config deployed. Skipping automatic launch; run with --start to apply the gesture preset.\n'
  fi
fi
