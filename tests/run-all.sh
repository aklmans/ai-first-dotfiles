#!/usr/bin/env bash
set -uo pipefail

# Runs every suite against two starting-state fixtures on this machine.
#
# `for t in tests/smoke/*.sh; do bash "$t"; done` runs them against whatever
# $HOME the person typing it happens to have, which on CI means a machine with
# nothing installed and on a contributor's laptop means something in between.
# Two suites passed that way for months while failing on a machine where
# author-full was actually deployed: the profile at $HOME/.config/ai-first
# outranks the sandbox config a test just wrote, so the real desk answered
# questions the test meant to ask about its own fixtures.
#
# Neither mode below inherits $HOME:
#
#   clean      nothing installed - what a stranger's Mac looks like, and CI
#   installed  author-full's profile in place - what the author's Mac looks like
#
# A suite that passes clean and fails installed is reading the machine instead
# of its fixtures. That is the bug this runner exists to make loud.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root" || exit 1

# Re-exec in a kernel-enforced boundary before ANY suite runs. Failure to enter
# it is fatal: fake HOME alone cannot isolate desktop IPC. Individual suites
# remain useful under this runner; don't use their PATH mocks as a sandbox.
if [ "${AI_FIRST_TEST_ISOLATED:-0}" != 1 ]; then
  sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/ai-first-test-boundary.XXXXXX")" || exit 1
  sandbox_root="$(cd "$sandbox_root" && pwd -P)"
  denied_root=""
  trap 'rm -rf "$sandbox_root"; [ -z "$denied_root" ] || rm -rf "$denied_root"' EXIT
  denied_root="$(mktemp -d "${TMPDIR:-/tmp}/ai-first-test-denied.XXXXXX")" || exit 1
  denied_root="$(cd "$denied_root" && pwd -P)"
  printf 'unchanged\n' >"$denied_root/canary"
  mkdir -p "$sandbox_root/home" "$sandbox_root/bin" "$sandbox_root/tmp"
  for name in aerospace hs sketchybar borders brew open defaults osascript pbcopy pbpaste launchctl sudo security curl wget npm npx bun docker; do
    cp "$repo_root/tests/deny-command.sh" "$sandbox_root/bin/$name" || exit 1
    chmod +x "$sandbox_root/bin/$name"
  done
  # Only these optional pure interpreters/utilities survive the caller's PATH.
  for name in rg lua; do
    tool="$(command -v "$name" || true)"
    [ -z "$tool" ] || ln -s "$tool" "$sandbox_root/bin/$name"
  done
  /usr/bin/sandbox-exec -D "TEST_ROOT=$sandbox_root" -f "$repo_root/tests/isolation.sb" \
    /usr/bin/env -i HOME="$sandbox_root/home" TMPDIR="$sandbox_root/tmp" \
    PATH="$sandbox_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    AI_FIRST_TEST_ISOLATED=1 AI_FIRST_TEST_ROOT="$sandbox_root" \
    AI_FIRST_TEST_DENIED_ROOT="$denied_root" \
    AEROSPACE_BIN="$sandbox_root/bin/aerospace" HS_BIN="$sandbox_root/bin/hs" \
    SKETCHYBAR_BIN="$sandbox_root/bin/sketchybar" DOTFILES_LAUNCHCTL="$sandbox_root/bin/launchctl" \
    /bin/bash "$0" "$@"
  exit "$?"
fi

# Verify denial even if someone incorrectly exports AI_FIRST_TEST_ISOLATED.
if /usr/bin/defaults read -g >/dev/null 2>&1; then
  printf 'Refusing tests: macOS command boundary is not active.\n' >&2
  exit 1
fi
if [ -z "${AI_FIRST_TEST_DENIED_ROOT:-}" ] ||
   (printf 'modified\n' >"$AI_FIRST_TEST_DENIED_ROOT/canary") 2>/dev/null ||
   [ "$(cat "$AI_FIRST_TEST_DENIED_ROOT/canary" 2>/dev/null)" != unchanged ]; then
  printf 'Refusing tests: filesystem write boundary is not active.\n' >&2
  exit 1
fi

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/ai-first-run-all.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

clean_home="$sandbox_root/clean"
installed_home="$sandbox_root/installed"
mkdir -p "$clean_home"

# Enough of an install for the profile layer to be live. Deploying the whole
# preset would be slower and would test the installer rather than the suites;
# profile.conf plus the reader it needs is what every leak so far went through.
mkdir -p "$installed_home/.config/ai-first"
cp -R "$repo_root/home/.config/ai-first/." "$installed_home/.config/ai-first/" || exit 1
cp "$repo_root/bootstrap/presets/author-full.conf" \
  "$installed_home/.config/ai-first/profile.conf" || exit 1

suites=(tests/smoke/*.sh home/.config/ai-router/tests/run.sh)
if [ "$#" -gt 0 ]; then
  suites=("$@")
  for suite in "${suites[@]}"; do
    case "$suite" in
      tests/smoke/*_smoke.sh|home/.config/ai-router/tests/run.sh) [ -f "$suite" ] || exit 64 ;;
      *) printf 'Unknown suite: %s\n' "$suite" >&2; exit 64 ;;
    esac
  done
fi

# Keep the heavyweight installer suites serial to bound process load. Their
# external commands must use fixture stubs, never the host's Homebrew/services.
serial_suites=" install_deploy_smoke.sh orchestration_smoke.sh "

# Serially the whole thing runs about five minutes per mode, which is long
# enough that people stop running it before pushing. Everything not named above
# builds its own sandbox under mktemp and shares nothing, so those go out
# together and the wall clock becomes the slowest one rather than the sum.
run_mode() {
  local mode="$1" mode_home="$2"
  local suite name outdir pids=""

  outdir="$sandbox_root/$mode"
  mkdir -p "$outdir"

  printf '\n== %s HOME ==\n' "$mode"
  for suite in "${suites[@]}"; do
    name="${suite##*/}"
    case "$serial_suites" in
      *" $name "*) continue ;;
    esac
    (
      if HOME="$mode_home" bash "$suite" >"$outdir/$name.out" 2>&1; then
        printf 'ok' >"$outdir/$name.status"
      else
        printf 'FAILED' >"$outdir/$name.status"
      fi
    ) &
    pids="$pids $!"
  done
  # No bare `wait`: it would also collect anything the caller left running, and
  # its status would say nothing about these. Statuses come off disk instead.
  local pid
  for pid in $pids; do
    wait "$pid"
  done

  for suite in "${suites[@]}"; do
    name="${suite##*/}"
    case "$serial_suites" in
      *" $name "*) ;;
      *) continue ;;
    esac
    if HOME="$mode_home" bash "$suite" >"$outdir/$name.out" 2>&1; then
      printf 'ok' >"$outdir/$name.status"
    else
      printf 'FAILED' >"$outdir/$name.status"
    fi
  done

  local mode_failures=0
  for suite in "${suites[@]}"; do
    name="${suite##*/}"
    if [ "$(cat "$outdir/$name.status" 2>/dev/null)" = "ok" ]; then
      report "$mode" "$name" 'ok'
    else
      report "$mode" "$name" 'FAILED'
      tail -20 "$outdir/$name.out" 2>/dev/null | sed 's/^/    /'
      mode_failures=$((mode_failures + 1))
    fi
  done
  return "$mode_failures"
}

failures=0
report() { printf '%-10s %-44s %s\n' "$1" "$2" "$3"; }

run_mode clean "$clean_home" || failures=$((failures + $?))
run_mode installed "$installed_home" || failures=$((failures + $?))

printf '\n'
if [ "$failures" -eq 0 ]; then
  printf 'All selected suites pass with clean and author-full fixture HOME (not hardware validation).\n'
  exit 0
fi
printf '%s suite run(s) failed.\n' "$failures"
printf 'A suite that is ok under clean and FAILED under installed is reading the\n'
printf 'machine rather than its own fixtures - pin HOME inside that suite.\n'
exit 1
