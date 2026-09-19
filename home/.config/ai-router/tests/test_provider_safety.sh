#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
setup_router_home
python3 -B "$test_dir/provider_safety.py" "$test_root" "$router_home" "$router"
