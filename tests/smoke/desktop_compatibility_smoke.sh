#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -B "$repo_root/tests/desktop_compatibility_test.py"
lua "$repo_root/tests/lua/recording_runtime.lua" "$repo_root"
