#!/usr/bin/env bash
set -euo pipefail
# Only operation records prove bounded file ownership. The old ledger remains
# a read-only manual recovery reference, never a system inverse.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -B "$script_dir/lib/maintenance.py" uninstall "$@"
