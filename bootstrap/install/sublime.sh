#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

if should_deploy; then
  deploy_repo_path \
    "$repo_root" \
    "home/Library/Application Support/Sublime Text/Packages/User/ai_first_sidebar.py" \
    "$HOME/Library/Application Support/Sublime Text/Packages/User/ai_first_sidebar.py" \
    "$stamp"

  deploy_repo_path \
    "$repo_root" \
    "home/Library/Application Support/Sublime Text/Packages/User/gui_path.py" \
    "$HOME/Library/Application Support/Sublime Text/Packages/User/gui_path.py" \
    "$stamp"

  deploy_repo_path \
    "$repo_root" \
    "home/Library/Application Support/Sublime Text/Packages/User/Terminal.sublime-settings" \
    "$HOME/Library/Application Support/Sublime Text/Packages/User/Terminal.sublime-settings" \
    "$stamp"

  deploy_repo_path \
    "$repo_root" \
    "home/Library/Application Support/Sublime Text/Packages/User/ZZ AI First (OSX).sublime-keymap" \
    "$HOME/Library/Application Support/Sublime Text/Packages/User/ZZ AI First (OSX).sublime-keymap" \
    "$stamp"
fi
