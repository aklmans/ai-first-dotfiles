#!/usr/bin/env bash
# Helper used by the agent menu to open a Mac app. It is not a text provider,
# so its health check always fails and the router never routes prompts here.
set -euo pipefail

if [ "${1:-}" = "--install-hint" ]; then
  printf '%s\n' "helper for the agent menu, not a text provider"
  exit 0
fi

if [ "${1:-}" = "--health-check" ]; then
  exit 1
fi

app_name="${1:-}"
if [ -z "$app_name" ]; then
  printf '%s\n' "Usage: app-opener.sh <App Name>" >&2
  exit 64
fi

/usr/bin/open -a "$app_name"
