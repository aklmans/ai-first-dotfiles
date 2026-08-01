#!/usr/bin/env bash
set -euo pipefail

# Covers the ai-router command line contract - the layer everything else sits
# on: hotkeys, the chooser, CI, and anyone piping into it from a shell.
#
# Why this exists: the router used to be reachable only through the macOS GUI.
# read_selection was the single input path, so `git diff | ai-router run
# commit-message` was impossible, osascript/pbcopy/pbpaste were unconditional
# hard dependencies, and every invocation went through an AppleScript Cmd+C
# that needs Accessibility permission. The properties pinned down here are:
#
#   1. Piped stdin reaches a provider, with no macOS-only command on PATH.
#   2. --from selection ignores stdin, so a GUI caller never reads a pipe its
#      launcher happened to open.
#   3. doctor names every provider, tells you how to install the missing ones,
#      and exits non-zero only when nothing is usable.
#   4. show prints the prompt file byte for byte - that is the trust story.
#   5. Dropping providers/<name>.sh in is all it takes to add a provider, and
#      providers/_template.sh is a working example of one.
#   6. The terminal used for agents comes from config.json, not from a
#      hard-coded "Warp".
#   7. Runtime data never lands in the config directory.
#
# Everything runs on /bin/bash so bash 3.2 regressions cannot hide, and every
# case works inside a throwaway AI_ROUTER_HOME.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
router_src="$repo_root/home/.config/ai-router"
router_rel="home/.config/ai-router/ai-router.sh"
system_bash="/bin/bash"

# --- the CLI must be exercised on bash 3.2, not Homebrew's bash 5 ------------

if [[ ! -x "$system_bash" ]]; then
  printf 'Missing %s; the router must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

system_bash_version="$("$system_bash" -c 'printf "%s\n" "$BASH_VERSION"')"
case "$system_bash_version" in
  3.2.*) ;;
  *)
    printf 'Expected %s to be bash 3.2, got %s.\n' "$system_bash" "$system_bash_version" >&2
    exit 1
    ;;
esac

# --- sandbox ----------------------------------------------------------------

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/ai-router-cli-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

# AI_ROUTER_HOME redirects the router's own config, but the machine profile is
# read from $HOME/.config/ai-first - deliberately, so that a preset outranks the
# repository's config.json. That makes the real $HOME an input to every case
# below: on a machine where author-full is installed, its AI_FIRST_TERMINAL_APP
# wins over the terminal a test just wrote into config.json. Pinning HOME to an
# empty directory is what makes the sandbox actually a sandbox. Found by running
# this suite on a machine with the config deployed; CI has nothing deployed and
# so could not see it.
HOME="$sandbox_root/home"
export HOME
mkdir -p "$HOME"

checks=0
failures=0

pass() {
  checks=$((checks + 1))
}

fail() {
  local message="$1"
  local detail="${2:-}"

  checks=$((checks + 1))
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$message" >&2
  if [[ -n "$detail" ]]; then
    printf -- '--- detail ---\n%s\n--------------\n' "$detail" >&2
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  case "$haystack" in
    *"$needle"*) pass ;;
    *) fail "$message" "expected to find: $needle"$'\n'"got: $haystack" ;;
  esac
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  case "$haystack" in
    *"$needle"*) fail "$message" "unexpected: $needle"$'\n'"in: $haystack" ;;
    *) pass ;;
  esac
}

assert_equal() {
  if [[ "$1" == "$2" ]]; then
    pass
  else
    fail "$3" "expected: $1"$'\n'"actual:   $2"
  fi
}

assert_missing() {
  if [[ -e "$1" ]]; then
    fail "$2" "path should not exist: $1"
  else
    pass
  fi
}

# Each case gets its own copy of the shipped router tree, so cases cannot see
# each other's state and the fixtures are the real prompts and providers.
new_router_home() {
  local name="$1"
  local home="$sandbox_root/$name"

  mkdir -p "$home"
  cp -R "$router_src/." "$home/"
  rm -rf "$home/catalogs" "$home/cache" "$home/state" "$home/logs"
  chmod +x "$home/ai-router.sh"
  chmod +x "$home"/providers/*.sh
  printf '%s' "$home"
}

# A provider that needs no network: upper-cases whatever it is given.
write_echo_provider() {
  local path="$1"
  cat >"$path" <<'PROVIDER'
#!/bin/sh
case "${1:-}" in
  --health-check) exit 0 ;;
  --install-hint) printf 'install: nothing to install\n'; exit 0 ;;
esac
printf 'ECHO:'
tr '[:lower:]' '[:upper:]'
PROVIDER
  chmod +x "$path"
}

# A prompt with no provider pinned, so routing comes from config.json alone.
# The shipped prompts pin claude/codex, which would send these cases to a real
# model over the network.
write_unpinned_prompt() {
  local home="$1"
  cat >"$home/prompts/smoke-echo.md" <<'PROMPT'
---
id: smoke-echo
title: Smoke Echo
description: routing fixture
output: preview
---

{{selection}}
PROMPT
}

set_provider_chain() {
  local home="$1"
  shift
  python3 - "$home/config.json" "$@" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    config = json.load(handle)
config.setdefault("providers", {})["default"] = sys.argv[2:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle, ensure_ascii=False, indent=2)
PY
}

set_config_value() {
  local home="$1"
  local dotted="$2"
  local value="$3"
  python3 - "$home/config.json" "$dotted" "$value" <<'PY'
import json
import sys

path, dotted, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as handle:
    config = json.load(handle)
node = config
parts = dotted.split(".")
for part in parts[:-1]:
    node = node.setdefault(part, {})
if value in {"true", "false"}:
    node[parts[-1]] = value == "true"
else:
    node[parts[-1]] = value
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle, ensure_ascii=False, indent=2)
PY
}

last_status=0
last_output=""

run_router() {
  local home="$1"
  shift
  last_status=0
  last_output="$(AI_ROUTER_HOME="$home" "$system_bash" "$home/ai-router.sh" "$@" 2>&1)" || last_status=$?
}

# --- 1. the reason this batch exists ----------------------------------------

case_stdin_reaches_a_provider() {
  local home
  home="$(new_router_home stdin-run)"
  write_echo_provider "$home/providers/stub.sh"
  write_unpinned_prompt "$home"
  set_provider_chain "$home" stub

  last_status=0
  last_output="$(printf 'hello from a pipe' |
    AI_ROUTER_HOME="$home" "$system_bash" "$home/ai-router.sh" run smoke-echo 2>&1)" || last_status=$?

  assert_equal 0 "$last_status" 'a piped run must succeed'
  assert_contains "$last_output" 'HELLO FROM A PIPE' 'the piped text must reach the provider'

  # The selection path must not have been touched at all.
  assert_contains "$(cat "$home/cache/selection-meta.env" 2>/dev/null || true)" 'source=stdin' \
    'the recorded input source must be stdin'

  local events
  events="$(cat "$home/logs/events.jsonl" 2>/dev/null || true)"
  assert_contains "$events" '"input_source": "stdin"' 'the event log must record stdin as the input'
}

# The list is deliberately the bare minimum a POSIX box has: no osascript, no
# pbcopy, no pbpaste - and no mkdir, chmod, tr or sort either.
case_runs_without_macos_commands() {
  local home minimal_bin candidate
  home="$(new_router_home no-macos)"
  minimal_bin="$sandbox_root/minimal-bin"
  mkdir -p "$minimal_bin"

  for tool in bash sh env cat sed awk grep find python3 date mktemp printf; do
    candidate="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$candidate" ]] && ln -sf "$candidate" "$minimal_bin/$tool"
  done

  last_status=0
  last_output="$(printf 'plain text input' |
    env -i HOME="$sandbox_root/fake-home" PATH="$minimal_bin" AI_ROUTER_HOME="$home" \
      "$system_bash" "$home/ai-router.sh" render summarize 2>&1)" || last_status=$?

  assert_equal 0 "$last_status" 'render must work without any macOS-only command'
  assert_contains "$last_output" 'plain text input' 'the piped text must be rendered into the prompt'
}

case_from_selection_ignores_stdin() {
  local home
  home="$(new_router_home from-selection)"

  last_status=0
  last_output="$(printf 'text from the pipe' |
    AI_ROUTER_SELECTION='text from the selection' AI_ROUTER_HOME="$home" \
      "$system_bash" "$home/ai-router.sh" render summarize --from selection 2>&1)" || last_status=$?

  assert_equal 0 "$last_status" '--from selection must succeed'
  assert_contains "$last_output" 'text from the selection' '--from selection must use the selection'
  assert_not_contains "$last_output" 'text from the pipe' '--from selection must not read stdin'
}

# --- 2. doctor --------------------------------------------------------------

case_doctor_without_any_provider() {
  local home
  home="$(new_router_home doctor-empty)"
  rm -f "$home"/providers/*.sh

  cat >"$home/providers/nothing.sh" <<'PROVIDER'
#!/bin/sh
case "${1:-}" in
  --health-check) exit 1 ;;
  --install-hint) printf 'install: brew install nothing\n'; exit 0 ;;
esac
exit 69
PROVIDER
  chmod +x "$home/providers/nothing.sh"

  run_router "$home" doctor

  assert_equal 1 "$last_status" 'doctor must exit non-zero when nothing is usable'
  assert_contains "$last_output" 'install: brew install nothing' \
    'doctor must print the exact command that fixes a missing provider'
  assert_contains "$last_output" 'No provider is ready' 'doctor must say so in plain words'
  assert_contains "$last_output" 'Try it now' 'doctor must end with something to copy and paste'
}

case_doctor_with_a_working_provider() {
  local home
  home="$(new_router_home doctor-ok)"
  rm -f "$home"/providers/*.sh
  write_echo_provider "$home/providers/stub.sh"

  run_router "$home" doctor

  assert_equal 0 "$last_status" 'doctor must exit 0 once a provider is ready'
  assert_contains "$last_output" '[ready]     stub' 'doctor must mark the working provider ready'
}

# --- 3. show ----------------------------------------------------------------

case_show_prints_the_file_verbatim() {
  local home shown
  home="$(new_router_home show)"

  shown="$sandbox_root/shown.md"
  AI_ROUTER_HOME="$home" "$system_bash" "$home/ai-router.sh" show summarize >"$shown" 2>/dev/null

  if diff -q "$home/prompts/summarize.md" "$shown" >/dev/null; then
    pass
  else
    fail 'show must print the prompt file byte for byte' "$(diff "$home/prompts/summarize.md" "$shown" || true)"
  fi

  run_router "$home" show no-such-prompt
  assert_equal 66 "$last_status" 'show must fail cleanly for an unknown prompt'
  assert_contains "$last_output" 'summarize' 'show must list what does exist'
}

# --- 4. a provider is a file you drop in ------------------------------------

case_template_provider_is_pluggable() {
  local home stub_bin
  home="$(new_router_home pluggable)"
  stub_bin="$sandbox_root/pluggable-bin"
  mkdir -p "$stub_bin"

  # The template names my-cli; providing that is all a copy of it should need.
  cat >"$stub_bin/my-cli" <<'STUB'
#!/bin/sh
shift 2>/dev/null || true
printf 'template provider answered\n'
STUB
  chmod +x "$stub_bin/my-cli"

  cp "$home/providers/_template.sh" "$home/providers/mytest.sh"
  chmod +x "$home/providers/mytest.sh"
  write_unpinned_prompt "$home"
  set_provider_chain "$home" mytest

  PATH="$stub_bin:$PATH" run_router "$home" list providers
  assert_contains "$last_output" 'mytest' 'a new adapter must be discovered'
  assert_not_contains "$last_output" '_template' 'the template itself must never be a routing target'

  last_status=0
  last_output="$(printf 'anything' |
    PATH="$stub_bin:$PATH" AI_ROUTER_HOME="$home" \
      "$system_bash" "$home/ai-router.sh" run smoke-echo 2>&1)" || last_status=$?

  assert_equal 0 "$last_status" 'a copy of the template must be executable as a provider'
  assert_contains "$last_output" 'template provider answered' \
    'the template contract must actually route a prompt'
}

# --- 5. the terminal is configuration, not a constant -----------------------

case_terminal_app_is_configurable() {
  local home stub_bin log
  home="$(new_router_home terminal)"
  stub_bin="$sandbox_root/terminal-bin"
  log="$sandbox_root/osascript.log"
  mkdir -p "$stub_bin"
  : >"$log"

  cat >"$stub_bin/osascript" <<STUB
#!/bin/sh
printf 'ARGS: %s\n' "\$*" >>"$log"
cat >>"$log"
exit 0
STUB
  chmod +x "$stub_bin/osascript"
  for tool in pbcopy pbpaste; do
    printf '#!/bin/sh\nexit 0\n' >"$stub_bin/$tool"
    chmod +x "$stub_bin/$tool"
  done

  set_config_value "$home" terminal.app Ghostty

  last_status=0
  PATH="$stub_bin:$PATH" AI_ROUTER_OSASCRIPT="$stub_bin/osascript" AI_ROUTER_HOME="$home" \
    "$system_bash" "$home/ai-router.sh" agent claude >/dev/null 2>&1 || last_status=$?

  assert_equal 0 "$last_status" 'launching an agent must succeed'

  local captured
  captured="$(cat "$log")"
  assert_not_contains "$captured" 'tell application "Warp"' \
    'a non-Warp terminal must never produce a Warp AppleScript'
  assert_not_contains "$captured" 'Warp' 'nothing about Warp may reach AppleScript'

  case "${OSTYPE:-}" in
    darwin*)
      assert_contains "$captured" 'Ghostty' 'the configured terminal must be the one addressed'
      ;;
    *)
      pass
      ;;
  esac
}

# --- 6. runtime data stays out of the config directory ----------------------

case_runtime_data_is_not_config() {
  local home state
  home="$(new_router_home runtime)"
  state="$sandbox_root/runtime-state"

  last_status=0
  last_output="$(printf 'some text' |
    AI_ROUTER_STATE_HOME="$state" AI_ROUTER_HOME="$home" \
      "$system_bash" "$home/ai-router.sh" render summarize 2>&1)" || last_status=$?

  assert_equal 0 "$last_status" 'render must succeed with a separate state directory'
  assert_missing "$home/cache" 'the config directory must not gain a cache directory'
  assert_missing "$home/state" 'the config directory must not gain a state directory'
  assert_missing "$home/logs" 'the config directory must not gain a logs directory'
  # catalogs are written by router_tools.py, not by the shell. Leaving it out
  # here is how a Python-side path escaped the move to the state directory and
  # kept rewriting ~/.config on every index.
  assert_missing "$home/catalogs" 'the config directory must not gain a catalogs directory'

  # index is the command that regenerates them, so exercise it directly rather
  # than trusting that render happened to trigger one.
  last_status=0
  AI_ROUTER_STATE_HOME="$state" AI_ROUTER_HOME="$home" \
    "$system_bash" "$home/ai-router.sh" index >/dev/null 2>&1 || last_status=$?
  assert_equal 0 "$last_status" 'index must succeed with a separate state directory'
  assert_missing "$home/catalogs" 'index must not write catalogs back into the config directory'

  if [[ -d "$state/catalogs" ]]; then
    pass
  else
    fail 'index must write catalogs under the state directory' "$(find "$state" -maxdepth 1 2>/dev/null || true)"
  fi

  if [[ -f "$state/cache/last-output.md" && -f "$state/state/usage.json" ]]; then
    pass
  else
    fail 'runtime data must be written under the state directory' "$(find "$state" -type f 2>/dev/null || true)"
  fi
}

# Upgrading an existing install must carry favorites and usage across.
case_legacy_runtime_is_migrated() {
  local home state
  home="$(new_router_home migrate)"
  state="$sandbox_root/migrate-state"

  mkdir -p "$home/state" "$home/logs/errors" "$state/logs/errors"
  printf '{"version":1,"items":[{"kind":"prompt","value":"ask","title":"Ask"}]}\n' >"$home/state/favorites.json"
  printf 'old error\n' >"$home/logs/errors/latest.log"

  last_status=0
  AI_ROUTER_STATE_HOME="$state" AI_ROUTER_HOME="$home" \
    "$system_bash" "$home/ai-router.sh" version >/dev/null 2>&1 || last_status=$?

  assert_equal 0 "$last_status" 'a router start must survive the migration'
  assert_contains "$(cat "$state/state/favorites.json" 2>/dev/null || true)" '"value":"ask"' \
    'favorites must survive the move to the state directory'
  assert_contains "$(cat "$state/logs/errors/latest.log" 2>/dev/null || true)" 'old error' \
    'nested log files must survive even when the target directory already exists'
  assert_missing "$home/state/favorites.json" 'the legacy copy must not be left behind'
}

# A switch that reads like a privacy switch has to be one. config.json used to
# carry privacy.log_full_selection, which controlled nothing at all.
case_privacy_switch_is_real() {
  local home
  home="$(new_router_home privacy)"

  printf 'logged text' | AI_ROUTER_HOME="$home" \
    "$system_bash" "$home/ai-router.sh" render summarize >/dev/null 2>&1
  if [[ -f "$home/logs/events.jsonl" ]]; then
    pass
  else
    fail 'events are logged by default'
  fi

  rm -f "$home/logs/events.jsonl"
  set_config_value "$home" privacy.log_events false

  printf 'logged text' | AI_ROUTER_HOME="$home" \
    "$system_bash" "$home/ai-router.sh" render summarize >/dev/null 2>&1
  assert_missing "$home/logs/events.jsonl" 'privacy.log_events false must stop the event log'
}

# --- run --------------------------------------------------------------------

case_stdin_reaches_a_provider
case_runs_without_macos_commands
case_from_selection_ignores_stdin
case_doctor_without_any_provider
case_doctor_with_a_working_provider
case_show_prints_the_file_verbatim
case_template_provider_is_pluggable
case_terminal_app_is_configurable
case_runtime_data_is_not_config
case_legacy_runtime_is_migrated
case_privacy_switch_is_real

if [[ "$failures" -gt 0 ]]; then
  printf '\nai_router_cli_smoke.sh: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi

printf 'ai_router_cli_smoke.sh: ok (%s checks on bash %s)\n' "$checks" "$system_bash_version"
