#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/_lib.sh"
setup_router_home

mkdir -p "$test_root/bin"
cat > "$test_root/bin/kimi" <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
cat > "$test_root/bin/gemini" <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
chmod +x "$test_root/bin/kimi" "$test_root/bin/gemini"
export PATH="$test_root/bin:$PATH"

cat > "$AI_ROUTER_HOME/prompts/fallback-test.md" <<'PROMPT'
---
id: fallback-test
title: Fallback Test
default_provider: kimi
fallback_provider: gemini
output: clipboard
---

{{selection}}
PROMPT

cat > "$AI_ROUTER_HOME/providers/kimi.sh" <<'PROVIDER'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--health-check" ]; then exit 0; fi
if [ "${1:-}" = "--text-contract" ]; then printf 'text-v1\n'; exit 0; fi
printf 'intentional failure\n' >&2
exit 70
PROVIDER

cat > "$AI_ROUTER_HOME/providers/gemini.sh" <<'PROVIDER'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--health-check" ]; then exit 0; fi
if [ "${1:-}" = "--text-contract" ]; then printf 'text-v1\n'; exit 0; fi
printf used > "$AI_ROUTER_HOME/fallback-used"
tr '[:lower:]' '[:upper:]'
PROVIDER
chmod +x "$AI_ROUTER_HOME/providers/kimi.sh" "$AI_ROUTER_HOME/providers/gemini.sh"

status=0
AI_ROUTER_SELECTION='fallback ok' "$router" run fallback-test > /dev/null 2>&1 || status=$?
[ "$status" = 64 ] || fail 'missing recipient must fail closed'
[ ! -e "$AI_ROUTER_HOME/fallback-used" ] || fail 'legacy fallback was contacted'

status=0
AI_ROUTER_SELECTION='fallback ok' "$router" run fallback-test --provider kimi > /dev/null 2>&1 || status=$?
[ "$status" = 70 ] || fail 'primary failure status lost'
[ ! -e "$AI_ROUTER_HOME/fallback-used" ] || fail 'unapproved fallback was contacted'

output="$(AI_ROUTER_SELECTION='fallback ok' "$router" run fallback-test --provider kimi --fallback gemini)"

assert_contains "$output" "FALLBACK OK" "fallback provider output"
assert_file "$AI_ROUTER_HOME/cache/last-output.md"

printf 'ok - provider fallback\n'
