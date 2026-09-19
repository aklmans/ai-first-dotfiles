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
if [ "${1:-}" = "--text-contract" ]; then printf 'text-v1\n'; exit 0; fi
printf 'FAILED_STDOUT_OPAQUE_PRIVATE_PAYLOAD\n'
printf 'failed reading /Users/alice/private/project/request.txt OPAQUE_PRIVATE_PAYLOAD\n' >&2
exit 70
PROVIDER
chmod +x "$AI_ROUTER_HOME/providers/kimi.sh"

if AI_ROUTER_DEBUG_FULL_LOG=1 AI_ROUTER_SELECTION='error input' "$router" run error-test --provider kimi >"$test_root/redaction.out" 2>"$test_root/redaction.err"; then
  fail "provider failure unexpectedly succeeded"
fi

assert_file "$AI_ROUTER_HOME/logs/errors/latest.log"
latest_error="$(cat "$AI_ROUTER_HOME/logs/errors/latest.log")"
assert_contains "$latest_error" 'failed (status 70); raw output discarded' 'safe failure metadata'
if [[ "$latest_error" == *"/Users/alice"* ]]; then
  fail "raw user path leaked into error log"
fi

if rg 'OPAQUE_PRIVATE_PAYLOAD|private/project/request' "$AI_ROUTER_HOME/logs" "$AI_ROUTER_HOME/cache" "$test_root/redaction.out" "$test_root/redaction.err"; then
  fail 'raw failure payload was retained (including legacy debug mode)'
fi

last_output="$(cat "$AI_ROUTER_HOME/cache/last-output.md")"
if [[ "$last_output" == *"/Users/alice"* ]]; then
  fail "raw user path leaked into last output"
fi

printf 'ok - error redaction\n'
