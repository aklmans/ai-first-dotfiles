#!/usr/bin/env bash
set -euo pipefail

# Set icon size and dock orientation
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock orientation -string left

# Set dock to auto-hide, and transparentize icons of hidden apps (⌘H)
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock showhidden -bool true

# Disable to show recents, and light-dot of running apps
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock show-process-indicators -bool false

# --- Unpin all apps
defaults write com.apple.dock persistent-apps -array ""
