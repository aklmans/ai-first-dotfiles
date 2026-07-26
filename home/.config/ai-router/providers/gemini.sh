#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--install-hint" ]; then
  printf '%s\n' "install: npm install -g @google/gemini-cli  (free tier is no longer offered)"
  exit 0
fi

if [ "${1:-}" = "--health-check" ]; then
  command -v gemini >/dev/null 2>&1 && gemini --version >/dev/null 2>&1
  exit
fi

if ! command -v gemini >/dev/null 2>&1; then
  printf '%s\n' "gemini CLI not found" >&2
  exit 69
fi

prompt="$(/bin/cat)"
if [ -z "$prompt" ]; then
  printf '%s\n' "empty prompt" >&2
  exit 64
fi

gemini --prompt "$prompt" --output-format text --skip-trust
