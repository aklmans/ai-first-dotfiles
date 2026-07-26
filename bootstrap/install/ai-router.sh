#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

echo "Installing AI Workflow Router"

if should_deploy; then
  deploy_repo_path "$repo_root" "home/.config/ai-router" "$HOME/.config/ai-router" "$stamp"

  chmod +x "$HOME/.config/ai-router/ai-router.sh"
  find "$HOME/.config/ai-router/providers" "$HOME/.config/ai-router/tests" -type f -name '*.sh' -exec chmod +x {} \;

  # The first run also moves any pre-2.4.0 catalogs/cache/state/logs out of
  # ~/.config and into the XDG state directory.
  "$HOME/.config/ai-router/ai-router.sh" index
  "$HOME/.config/ai-router/ai-router.sh" export-snippets all
fi

if should_install; then
  # Ends the install with the one thing a new user needs to know: which
  # providers are usable and the exact command to install the rest.
  "$HOME/.config/ai-router/ai-router.sh" doctor || true
fi

echo "Finished installing AI Workflow Router"
