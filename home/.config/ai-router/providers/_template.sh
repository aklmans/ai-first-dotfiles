#!/usr/bin/env bash
# Copy this file to <your-provider>.sh, make it executable, and it is a
# provider: `ai-router.sh doctor` and `list providers` pick it up, and
# `providers.default` in config.json can route to it. Files starting with "_"
# are ignored, so this template never routes anywhere itself.
#
# Contract: read the prompt on stdin, write the answer on stdout, exit 0.
#   --health-check   exit 0 when this provider can actually be used
#   --install-hint   one line telling a new user how to get it
set -euo pipefail

case "${1:-}" in
  --health-check)
    command -v my-cli >/dev/null 2>&1
    exit
    ;;
  --install-hint)
    printf '%s\n' "install: brew install my-cli"
    exit 0
    ;;
esac

prompt="$(/bin/cat)"
if [ -z "$prompt" ]; then
  printf '%s\n' "empty prompt" >&2
  exit 64
fi

# Anything that turns a prompt into text works here: a CLI, a curl call to your
# own endpoint, an ssh command to a box with a GPU.
my-cli --prompt "$prompt"
