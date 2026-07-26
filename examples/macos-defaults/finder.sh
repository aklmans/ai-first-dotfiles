#!/usr/bin/env bash
set -euo pipefail

# Allow quitting via ⌘Q
defaults write com.apple.finder QuitMenuItem -bool true

# Disable warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show all files and their extensions
defaults write com.apple.finder AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool false

# Show path bar, and layout as multi-column
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string clmv

# Search in current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string SCcf

# --- Keep the desktop clean
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false

# Show directories first
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# New window use the $HOME path
defaults write com.apple.finder NewWindowTarget -string PfHm
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"

# Allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Show metadata info, but not preview in info panel
defaults write com.apple.finder FXInfoPanesExpanded -dict MetaData -bool true Preview -bool false
