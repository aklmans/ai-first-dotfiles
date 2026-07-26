#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

brew_install_cask hammerspoon

if should_deploy; then
  deploy_repo_path "$repo_root" "home/.hammerspoon" "$HOME/.hammerspoon" "$stamp"
fi

# Launching an app is an install step. --deploy-only writes config and nothing
# else, so deploying into a fresh checkout never opens a window.
if should_install; then
  if ! open -a Hammerspoon 2>/dev/null; then
    printf 'Hammerspoon is not installed yet; skipping its launch. Start it yourself once it is.\n'
  fi
fi

cat <<'EOF'

Hammerspoon automation notes:
- Allow Accessibility and Automation permissions when macOS prompts.
- Hammerspoon clears SketchyBar AI attention state by writing clear requests; it does not need Full Disk Access for notification databases.
- If Hammerspoon is already running, reload its config from the menu bar icon.
EOF
