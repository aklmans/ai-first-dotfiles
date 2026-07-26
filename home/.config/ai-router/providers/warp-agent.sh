#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--install-hint" ]; then
  printf '%s\n' "not a text provider: open Warp Agent from the Coding Agent menu"
  exit 0
fi

if [ "${1:-}" = "--health-check" ]; then
  exit 1
fi

printf '%s\n' "Warp Agent provider is a placeholder. Use the Coding Agent menu to open Warp and invoke Warp Agent manually." >&2
exit 69
