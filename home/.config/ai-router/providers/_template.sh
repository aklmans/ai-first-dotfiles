#!/usr/bin/env bash
# Copy this file to <your-provider>.sh, make it executable, and it is a
# provider: `ai-router.sh doctor` and `list providers` pick it up, and
# `run ... --provider <name>` can route to it after review. Files starting with "_"
# are ignored, so this template never routes anywhere itself.
#
# Contract: read the prompt on stdin, write the answer on stdout, exit 0.
#   --health-check   exit 0 when this provider can actually be used
#   --install-hint   one line telling a new user how to get it
#   --text-contract  print text-v1 ONLY after verifying your adapter below:
#      explicit stdin only, no tools/hooks/MCP/project discovery, known recipient,
#      no daemonization and no hidden fallback or prompt/session/error logging.
# This marker is an assertion by trusted local code, NOT a sandbox or proof.
set -euo pipefail

case "${1:-}" in
  --text-contract)
    # After review, replace this refusal with: printf 'text-v1\n'; exit 0
    exit 78
    ;;
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

# Keep input off argv. Replace this with a reviewed text-only API/client.
# Do not wrap a coding agent and assume "read-only" disables file reads/tools.
printf '%s' "$prompt" | my-cli
