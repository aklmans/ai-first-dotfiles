#!/usr/bin/env bash
set -euo pipefail

# Read-only. Recording is a task role, not necessarily a third physical screen.
# Use the same profile, overlay and environment precedence as AeroSpace.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/layout.sh"
aerospace_layout_load_config

for role_entry in $AEROSPACE_WORKSPACE_ROLE_MAP; do
  if [ "${role_entry%%:*}" = 'stage' ]; then
    if ! aerospace_layout_workspace_for_semantic_role stage; then
      printf 'Recording role stage must name a configured workspace.\n' >&2
      exit 65
    fi
    exit 0
  fi
done

# Compatibility for profiles that predate task roles. An explicitly invalid
# semantic role above is an error, not permission to move to another workspace.
for workspace in $AEROSPACE_STAGE_WORKSPACES; do
  printf '%s\n' "$workspace"
  exit 0
done
for group in "$AEROSPACE_SIDE_WORKSPACES" "$AEROSPACE_MAIN_WORKSPACES"; do
  last_workspace=''
  for workspace in $group; do last_workspace="$workspace"; done
  if [ -n "$last_workspace" ]; then
    printf '%s\n' "$last_workspace"
    exit 0
  fi
done
printf 'No recording workspace is configured.\n' >&2
exit 65
