#!/usr/bin/env bash
# Quarantined text adapter. An installed/authenticated CLI is not a verified
# no-tools/no-project-discovery interface. Keep render and manual agent use.
# Re-enable only with version-scoped isolation and recipient tests.
set -euo pipefail

case "${1:-}" in
  --install-hint)
    printf '%s\n' "text execution quarantined: gemini; use render and review input in your chosen client"
    exit 0
    ;;
esac

printf '%s\n' "gemini: text isolation/recipient contract is unverified; no request sent" >&2
exit 78
