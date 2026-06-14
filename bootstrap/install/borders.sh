#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

target_path="$HOME/.config/borders"
borders_start_service="${BORDERS_START_SERVICE:-0}"

ensure_brew_tap felixkratz/formulae
brew_install borders

if should_deploy; then
  deploy_repo_path "$repo_root" "home/.config/borders" "$target_path" "$stamp"
fi

if should_install || should_deploy; then
  if [[ "$borders_start_service" == "1" ]]; then
    brew services start borders
  else
    brew services stop borders >/dev/null 2>&1 || true
    printf 'Borders service left stopped. Set BORDERS_START_SERVICE=1 to start it from this installer.\n'
  fi
fi
