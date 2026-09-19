#!/usr/bin/env bash
set -euo pipefail
# IPC acts on the current user's running desktop, NOT the HOME used to render.
if [ "${1:-}" != --apply ] || [ "$#" -ne 1 ]; then
    printf 'Reload the current user desktop (not a sandbox HOME): activate.sh --apply\n'
    exit 64
fi
AEROSPACE_BIN="${AEROSPACE_BIN:-aerospace}"
HS_BIN="${HS_BIN:-hs}"
"$AEROSPACE_BIN" reload-config --dry-run --no-gui
"$AEROSPACE_BIN" reload-config
if [ -f "$HOME/.hammerspoon/init.lua" ] && command -v "$HS_BIN" >/dev/null 2>&1; then
    "$HS_BIN" -c 'hs.reload()'
fi
