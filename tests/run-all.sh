#!/usr/bin/env bash
set -uo pipefail

# Runs every suite against both machines this repository has to be true on.
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

# These two run the real installers, which means real `brew` queries and real
# service lookups. Their sandboxes do not overlap, but Homebrew's does: two at
# once contend for machine-wide state that has nothing to do with either test,
# and the loser reports a failure that says nothing about this repository.
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
  printf 'All suites pass on a clean machine and on one with author-full installed.\n'
  exit 0
fi
printf '%s suite run(s) failed.\n' "$failures"
printf 'A suite that is ok under clean and FAILED under installed is reading the\n'
printf 'machine rather than its own fixtures - pin HOME inside that suite.\n'
exit 1
