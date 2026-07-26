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

# `brew services` is a Homebrew command, so it belongs behind should_brew:
# --deploy-only and --no-brew both promise not to run any. Stopping a service
# the user may have started themselves is exactly the kind of thing a config
# deployment must not do.
if should_brew; then
  if [[ "$borders_start_service" == "1" ]]; then
    if ! brew services start borders; then
      printf 'Could not start the borders service. Start it yourself:\n  brew services start borders\n' >&2
    fi
  else
    brew services stop borders >/dev/null 2>&1 || true
    printf 'Borders service left stopped. Set BORDERS_START_SERVICE=1 to start it from this installer.\n'
  fi
else
  printf 'Skipping the borders service. Set BORDERS_START_SERVICE=1 and re-run without --no-brew to start it.\n'
fi
