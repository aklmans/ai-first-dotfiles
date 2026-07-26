#!/usr/bin/env bash
set -euo pipefail

# Sort by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string CPUUsage
defaults write com.apple.ActivityMonitor SortDirection -int 0
