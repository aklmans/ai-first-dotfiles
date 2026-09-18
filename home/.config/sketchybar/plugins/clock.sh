#!/bin/bash

# Item scripts run in separate processes; exports from sketchybarrc alone do
# not update the already-running SketchyBar daemon's environment.
AI_FIRST_PROFILE_LIB="${AI_FIRST_PROFILE_LIB:-$HOME/.config/ai-first/lib/profile.sh}"
if [ -r "$AI_FIRST_PROFILE_LIB" ]; then
  source "$AI_FIRST_PROFILE_LIB"
fi

if [ "${AI_FIRST_CLOCK_SECONDS:-1}" = '0' ]; then
  LABEL=$(date '+%H:%M')
else
  LABEL=$(date '+%H:%M:%S')
fi
sketchybar --set "$NAME" label="$LABEL"
