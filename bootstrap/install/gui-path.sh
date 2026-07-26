#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

label="com.ai-first-dotfiles.gui-path"
plist="$HOME/Library/LaunchAgents/com.ai-first-dotfiles.gui-path.plist"
uid="$(id -u)"

# Homebrew first, then whatever the GUI session already had. Prepending rather
# than replacing matters: `launchctl setenv PATH <value>` has no append form, so
# the previous version of this module simply overwrote the session PATH and took
# out any other entry - a Nix profile, ~/.local/bin, a second package manager -
# that had been put there. Apple Silicon prefix; bootstrap/setup.sh refuses to
# install on Intel, see require_prerequisites in bootstrap/lib/common.sh.
gui_path_prefix="/opt/homebrew/bin:/opt/homebrew/sbin"
gui_path_fallback="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if should_deploy; then
  deploy_repo_path "$repo_root" \
    "home/Library/LaunchAgents/com.ai-first-dotfiles.gui-path.plist" \
    "$plist" \
    "$stamp"
fi

if should_install; then
  # Same computation the plist performs at login, applied to the session that is
  # running now so GUI apps started today see it without a logout.
  current_gui_path="$(/bin/launchctl getenv PATH || true)"
  case ":${current_gui_path}:" in
    *:/opt/homebrew/bin:*)
      printf 'GUI launchd PATH already includes Homebrew: %s\n' "$current_gui_path"
      ;;
    *)
      /bin/launchctl setenv PATH "$gui_path_prefix:${current_gui_path:-$gui_path_fallback}"
      printf 'GUI launchd PATH set to: %s\n' "$(/bin/launchctl getenv PATH || true)"
      ;;
  esac

  if [[ -f "$plist" ]]; then
    /bin/launchctl bootout "gui/$uid" "$plist" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/$uid" "$plist" >/dev/null 2>&1 || true
    /bin/launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>&1 || true
  fi

  printf 'Restart GUI apps after this step so they inherit the updated PATH.\n'
fi
