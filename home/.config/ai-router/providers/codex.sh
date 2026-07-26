#!/usr/bin/env bash
# Codex as a text provider. It used to be opt-in because `codex exec` is a
# coding agent and answering "summarize this" should not be able to touch the
# disk. That is now enforced instead of avoided: read-only sandbox, no session
# files, and only the agent's final message reaches stdout.
#
# AI_ROUTER_ENABLE_CODEX_PROVIDER=0 turns it off again.
set -euo pipefail

if [ "${1:-}" = "--install-hint" ]; then
  printf '%s\n' "install: npm install -g @openai/codex && codex login"
  exit 0
fi

if [ "${1:-}" = "--health-check" ]; then
  [ "${AI_ROUTER_ENABLE_CODEX_PROVIDER:-1}" != "0" ] &&
    command -v codex >/dev/null 2>&1 &&
    codex --version >/dev/null 2>&1
  exit
fi

if ! command -v codex >/dev/null 2>&1; then
  printf '%s\n' "codex CLI not found" >&2
  exit 69
fi

if [ "${AI_ROUTER_ENABLE_CODEX_PROVIDER:-1}" = "0" ]; then
  printf '%s\n' "codex text provider is disabled (AI_ROUTER_ENABLE_CODEX_PROVIDER=0)" >&2
  exit 69
fi

prompt="$(/bin/cat)"
if [ -z "$prompt" ]; then
  printf '%s\n' "empty prompt" >&2
  exit 64
fi

last_message="$(mktemp "${TMPDIR:-/tmp}/ai-router-codex.XXXXXX")"
transcript="$(mktemp "${TMPDIR:-/tmp}/ai-router-codex-log.XXXXXX")"
trap 'rm -f "$last_message" "$transcript"' EXIT

# stdin is already consumed above; hand codex /dev/null so it does not wait on
# the pipe. The session transcript is only surfaced when something failed.
status=0
codex exec \
  --ephemeral \
  --skip-git-repo-check \
  --color never \
  --sandbox read-only \
  --output-last-message "$last_message" \
  "$prompt" </dev/null >/dev/null 2>"$transcript" || status=$?

if [ "$status" -ne 0 ]; then
  /bin/cat "$transcript" >&2
  exit "$status"
fi

if [ ! -s "$last_message" ]; then
  printf '%s\n' "codex returned no final message" >&2
  /bin/cat "$transcript" >&2
  exit 70
fi

/bin/cat "$last_message"
