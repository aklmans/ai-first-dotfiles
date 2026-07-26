#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--install-hint" ]; then
  printf '%s\n' "install: npm install -g @anthropic-ai/claude-code  (then run: claude)"
  exit 0
fi

if [ "${1:-}" = "--health-check" ]; then
  command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1
  exit
fi

if ! command -v claude >/dev/null 2>&1; then
  printf '%s\n' "claude CLI not found" >&2
  exit 69
fi

prompt="$(/bin/cat)"
if [ -z "$prompt" ]; then
  printf '%s\n' "empty prompt" >&2
  exit 64
fi

claude --print "$prompt"

