#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/_lib.sh"
setup_router_home

mkdir -p "$test_root/bin"
cat > "$test_root/bin/kimi" <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
chmod +x "$test_root/bin/kimi"
export PATH="$test_root/bin:$PATH"

cat > "$AI_ROUTER_HOME/prompts/error-test.md" <<'PROMPT'
---
id: error-test
title: Error Test
default_provider: kimi
output: clipboard
---

{{selection}}
PROMPT

cat > "$AI_ROUTER_HOME/providers/kimi.sh" <<'PROVIDER'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--health-check" ]; then exit 0; fi
printf 'failed reading /Users/alice/private/project/request.txt\n' >&2
exit 70
PROVIDER
chmod +x "$AI_ROUTER_HOME/providers/kimi.sh"

if AI_ROUTER_SELECTION='error input' "$router" run error-test >/tmp/ai-router-redaction.out 2>/tmp/ai-router-redaction.err; then
  fail "provider failure unexpectedly succeeded"
fi

assert_file "$AI_ROUTER_HOME/logs/errors/latest.log"
latest_error="$(cat "$AI_ROUTER_HOME/logs/errors/latest.log")"
assert_contains "$latest_error" "/Users/***/private/project/request.txt" "sanitized error log"
if [[ "$latest_error" == *"/Users/alice"* ]]; then
  fail "raw user path leaked into error log"
fi

last_output="$(cat "$AI_ROUTER_HOME/cache/last-output.md")"
if [[ "$last_output" == *"/Users/alice"* ]]; then
  fail "raw user path leaked into last output"
fi

printf 'ok - error redaction\n'
