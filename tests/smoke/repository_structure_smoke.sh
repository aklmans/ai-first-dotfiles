#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

require_dir() {
  local path="$1"
  if [[ ! -d "$repo_root/$path" ]]; then
    printf 'Expected directory missing: %s\n' "$path" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  if [[ ! -f "$repo_root/$path" ]]; then
    printf 'Expected file missing: %s\n' "$path" >&2
    exit 1
  fi
}

require_absent() {
  local path="$1"
  if [[ -e "$repo_root/$path" ]]; then
    printf 'Unexpected path still tracked: %s\n' "$path" >&2
    exit 1
  fi
}

require_dir home
require_dir bootstrap
require_dir manifests
require_dir tests
require_dir tests/smoke
require_dir docs
require_dir docs/tools
require_dir docs/tools/current-workflow
require_dir home/Library
require_dir home/Library/LaunchAgents
require_dir "home/Library/Application Support"
require_dir "home/Library/Application Support/Sublime Text"
require_dir "home/Library/Application Support/Sublime Text/Packages"
require_dir "home/Library/Application Support/Sublime Text/Packages/User"
require_dir home/.config
require_dir home/.config/ai-router
require_dir home/.config/kaku
require_dir home/.config/yazi
require_dir home/.config/zsh
require_dir home/.config/zsh/completions
require_dir home/.config/sketchybar
require_dir home/.config/sketchybar/lib
require_dir home/.config/borders
require_dir home/.config/aerospace
require_dir home/.config/karabiner
require_dir home/.config/mpv
require_dir home/.warp
require_dir bootstrap/install
require_dir bootstrap/macos
require_dir manifests/app-store
require_dir home/.hammerspoon

require_file home/.zshenv
require_file home/.ideavimrc
require_file home/Library/LaunchAgents/com.aklman.gui-path.plist
require_file "home/Library/Application Support/Sublime Text/Packages/User/gui_path.py"
require_file "home/Library/Application Support/Sublime Text/Packages/User/Terminal.sublime-settings"
require_file "home/Library/Application Support/Sublime Text/Packages/User/Default (OSX).sublime-keymap"
require_file home/.config/zsh/.zprofile
require_file home/.config/zsh/.zshrc
require_file home/.config/zsh/env.zsh
require_file home/.config/zsh/plugins.zsh
require_file home/.config/zsh/aliases.zsh
require_file home/.config/zsh/functions.zsh
require_file home/.config/zsh/personal.zsh
require_file home/.config/zsh/codex-widget.zsh
require_file home/.config/zsh/completions/_openclaw

require_file home/.config/ai-router/ai-router.sh
require_file home/.config/ai-router/README.md
require_file home/.config/ai-router/ROADMAP.md
require_file home/.config/ai-router/config.json

require_file home/.config/kaku/kaku.lua
require_file home/.config/kaku/assistant.toml
require_file home/.warp/keybindings.yaml
require_file home/.config/yazi/init.lua
require_file home/.config/yazi/yazi.toml
require_file home/.config/ai-router/providers/app-opener.sh
require_file home/.config/ai-router/providers/claude.sh
require_file home/.config/ai-router/providers/codex.sh
require_file home/.config/ai-router/providers/gemini.sh
require_file home/.config/ai-router/providers/kimi.sh
require_file home/.config/ai-router/providers/junie.sh
require_file home/.config/ai-router/providers/warp-agent.sh

require_file home/.config/sketchybar/sketchybarrc
require_file home/.config/sketchybar/colors.sh
require_file home/.config/sketchybar/lib/display-resolver.sh
require_file home/.config/sketchybar/items/ai_notifications.sh
require_file home/.config/sketchybar/plugins/ai_app_notifications.sh
require_file home/.config/borders/bordersrc
require_file home/.config/aerospace/app-defaults.sh
require_file home/.config/aerospace/reveal-app.sh
require_file home/.aerospace.toml

require_file home/.config/karabiner/karabiner.json
require_file home/.config/karabiner/CapsLock-AI-Lite.md
require_file home/.hammerspoon/init.lua
require_file home/.hammerspoon/ai_hotkeys.lua
require_file home/.hammerspoon/app_reveal.lua
require_file home/.config/mpv/mpv.conf
require_file home/.config/mpv/input.conf
require_file bootstrap/brew.sh
require_file bootstrap/setup.sh
require_file bootstrap/app-store.sh

require_file bootstrap/install/ai-router.sh
require_file bootstrap/install/borders.sh
require_file bootstrap/install/gui-path.sh
require_file bootstrap/install/karabiner.sh
require_file bootstrap/install/warp.sh
require_file bootstrap/install/hammerspoon.sh
require_file bootstrap/install/aerospace.sh
require_file bootstrap/install/sketchybar.sh
require_file bootstrap/install/ideavim.sh
require_file bootstrap/install/sublime.sh
require_file bootstrap/install/zsh.sh
require_file bootstrap/install/mpv.sh
require_file bootstrap/install/kaku.sh
require_file bootstrap/install/yazi.sh

require_file manifests/app-store/mas-default.txt
require_file manifests/app-store/mas-large.txt
require_file LICENSE
require_file README.md
require_file docs/shortcuts.md

require_file tests/smoke/ai_router_exports_smoke.sh
require_file tests/smoke/aerospace_workflow_smoke.sh
require_file tests/smoke/repository_structure_smoke.sh
require_file tests/smoke/install_script_syntax_smoke.sh
require_file tests/smoke/install_script_side_effects_smoke.sh
require_file tests/smoke/privacy_scan_smoke.sh

require_absent home/.config/skhd
require_absent home/.config/yabai
require_absent home/.config/wezterm
require_absent home/.config/oh-my-posh
require_absent home/.config/warp
require_absent home/.config/skhd.sh
require_absent bootstrap/install/skhd.sh
require_absent bootstrap/install/yabai.sh
require_absent bootstrap/install/oh-my-posh.sh
require_absent home/.config/aerospace/warp-launch-agent.sh
require_absent bootstrap/install/warp-launch-agent.sh
require_absent home/.config/ai-router/cache
require_absent home/.config/ai-router/logs
require_absent home/.config/ai-router/state
require_absent home/.config/ai-router/catalogs
require_absent apps
require_absent docs/tools/wezterm
require_absent docs/tools/skhd
require_absent docs/tools/yabai
require_absent docs/tools/oh-my-posh

if rg -n 'status brew github\.bell wifi' "$repo_root/home/.config/sketchybar/items/volume.sh"; then
  printf 'SketchyBar volume bracket references stale status items\n' >&2
  exit 1
fi
