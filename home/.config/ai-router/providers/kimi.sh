#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--install-hint" ]; then
  printf '%s\n' "install: see the Kimi CLI docs; needs a Moonshot API key"
  exit 0
fi

if [ "${1:-}" = "--health-check" ]; then
  command -v kimi >/dev/null 2>&1 && kimi --version >/dev/null 2>&1
  exit
fi

if ! command -v kimi >/dev/null 2>&1; then
  printf '%s\n' "kimi CLI not found" >&2
  exit 69
fi

prompt="$(/bin/cat)"
if [ -z "$prompt" ]; then
  printf '%s\n' "empty prompt" >&2
  exit 64
fi

kimi --quiet --prompt "$prompt"

