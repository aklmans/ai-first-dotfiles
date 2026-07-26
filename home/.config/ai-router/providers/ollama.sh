#!/usr/bin/env bash
# Local models, no account and no network. Pick the model with
# AI_ROUTER_OLLAMA_MODEL; the health check fails unless that model is pulled,
# so the router falls through to the next provider instead of erroring.
set -euo pipefail

model="${AI_ROUTER_OLLAMA_MODEL:-llama3.2}"

has_model() {
  ollama list 2>/dev/null | awk -v want="$model" '
    NR > 1 {
      name = $1
      sub(/:latest$/, "", name)
      if (name == want || $1 == want) { found = 1 }
    }
    END { exit found ? 0 : 1 }
  '
}

case "${1:-}" in
  --health-check)
    command -v ollama >/dev/null 2>&1 && has_model
    exit
    ;;
  --install-hint)
    printf 'install: brew install ollama && ollama pull %s\n' "$model"
    exit 0
    ;;
esac

if ! command -v ollama >/dev/null 2>&1; then
  printf '%s\n' "ollama CLI not found" >&2
  exit 69
fi

prompt="$(/bin/cat)"
if [ -z "$prompt" ]; then
  printf '%s\n' "empty prompt" >&2
  exit 64
fi

printf '%s' "$prompt" | ollama run "$model"
