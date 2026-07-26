#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--install-hint" ]; then
  printf '%s\n' "install: JetBrains Junie CLI, then AI_ROUTER_ENABLE_JUNIE_PROVIDER=1"
  exit 0
fi

if [ "${1:-}" = "--health-check" ]; then
  [ "${AI_ROUTER_ENABLE_JUNIE_PROVIDER:-0}" = "1" ] && command -v junie >/dev/null 2>&1 && junie --version >/dev/null 2>&1
  exit
fi

if ! command -v junie >/dev/null 2>&1; then
  printf '%s\n' "junie CLI not found" >&2
  exit 69
fi

if [ "${AI_ROUTER_ENABLE_JUNIE_PROVIDER:-0}" != "1" ]; then
  printf '%s\n' "junie text provider is disabled by default; use the Coding Agent menu, or set AI_ROUTER_ENABLE_JUNIE_PROVIDER=1." >&2
  exit 69
fi

prompt="$(/bin/cat)"
junie --task "$prompt"

