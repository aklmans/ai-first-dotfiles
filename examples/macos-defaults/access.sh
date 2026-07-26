#!/usr/bin/env bash
set -euo pipefail

# Set the cursor size
defaults write com.apple.universalaccess mouseDriverCursorSize -float 1.5

# Disable crash reporter
defaults write com.apple.CrashReporter DialogType -string none

# Disable personalized advertising
defaults write com.apple.AdLib forceLimitAdTracking -bool true
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
