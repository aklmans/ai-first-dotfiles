#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

brew_install_cask karabiner-elements

# ---------------------------------------------------------------------------
# Why this module deploys one file and not the directory
#
# ~/.config/karabiner/karabiner.json is not a config file a dotfiles repo may
# own. Karabiner-Elements reads *and writes* it: every profile, every device
# override and every rule the user enabled in the GUI lives in that one file.
# Copying this repository's version over it does not merge anything - it
# replaces the user's entire keyboard driver configuration, and Karabiner is
# the driver, so a bad write is a keyboard that stops behaving as its owner
# expects.
#
# So the deploy ships the rules as a complex-modifications asset instead.
# Karabiner scans ~/.config/karabiner/assets/complex_modifications/ and lists
# whatever it finds under Complex Modifications -> Add rule. Dropping a file
# there adds an option; it changes no active mapping until the user enables it,
# and it touches no profile they already have.
#
# home/.config/karabiner/karabiner.json in this repo is a reference copy of the
# profile these rules produce. It is deliberately not deployed.
# ---------------------------------------------------------------------------

if should_deploy; then
  deploy_repo_path "$repo_root" \
    "home/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json" \
    "$HOME/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json" \
    "$stamp"

  cat <<'EOF'
The CapsLock AI Lite rules are installed but not active yet. Nothing this repo
deploys can enable them for you, because enabling a rule rewrites the profile
Karabiner is currently running.

To turn them on:

  Karabiner-Elements -> Complex Modifications -> Add rule
  -> "CapsLock AI Lite (ai-first-dotfiles)" -> Enable All

Read what each rule does first: home/.config/karabiner/CapsLock-AI-Lite.md
EOF
fi
