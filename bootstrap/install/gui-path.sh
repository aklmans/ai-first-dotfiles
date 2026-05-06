#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

gui_path="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
plist="$HOME/Library/LaunchAgents/com.aklman.gui-path.plist"
label="com.aklman.gui-path"
uid="$(id -u)"

if should_deploy; then
  deploy_repo_path "$repo_root" "home/Library/LaunchAgents/com.aklman.gui-path.plist" "$plist" "$stamp"
fi

if should_install; then
  /bin/launchctl setenv PATH "$gui_path"

  if [[ -f "$plist" ]]; then
    /bin/launchctl bootout "gui/$uid" "$plist" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/$uid" "$plist" >/dev/null 2>&1 || true
    /bin/launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>&1 || true
  fi

  printf 'GUI launchd PATH set to: %s\n' "$gui_path"
  printf 'Restart GUI apps after this step so they inherit the updated PATH.\n'
fi
