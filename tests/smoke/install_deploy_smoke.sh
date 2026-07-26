#!/usr/bin/env bash
set -euo pipefail

# Executes every bootstrap/install script for real, in an isolated HOME, using
# /bin/bash (bash 3.2) rather than whatever newer bash happens to be on PATH.
#
# Why this exists: the other smoke tests only run `bash -n`, so a blocker-level
# runtime bug once shipped with a fully green suite.
# bootstrap/install/bettertouchtool.sh expanded an empty array as
# "${args[@]}", which bash 3.2 treats as an unbound variable under `set -u`.
# `setup.sh all` aborted there, before hammerspoon and ai-router, so the
# CapsLock AI layer never installed. Syntax checks cannot see that; only
# running the script can.
#
# Everything that would touch the machine (brew, open, defaults, curl, git,
# make, ya) is replaced by a stub on PATH, so no package is installed, no app
# is launched, and no user default is written.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
system_bash="/bin/bash"

# --- the scripts must be exercised on bash 3.2, not Homebrew's bash 5 --------

if [[ ! -x "$system_bash" ]]; then
  printf 'Missing %s; install scripts must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

system_bash_version="$("$system_bash" -c 'printf "%s\n" "$BASH_VERSION"')"
case "$system_bash_version" in
  3.2.*)
    ;;
  *)
    printf 'Expected %s to be bash 3.2, got %s.\n' "$system_bash" "$system_bash_version" >&2
    printf 'This test only has value while it runs on the bash macOS ships.\n' >&2
    exit 1
    ;;
esac

# --- sandbox ----------------------------------------------------------------

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/install-deploy-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

stub_dir="$sandbox_root/stub-bin"
stub_log="$sandbox_root/stub-calls.log"
mkdir -p "$stub_dir"
: >"$stub_log"

write_generic_stub() {
  local name="$1"
  cat >"$stub_dir/$name" <<'STUB'
#!/bin/sh
# Sandbox stub: record the call, succeed, touch nothing outside the sandbox.
printf '%s %s\n' "${0##*/}" "$*" >>"${DOTFILES_STUB_LOG:-/dev/null}"
exit 0
STUB
  chmod +x "$stub_dir/$name"
}

# `sudo` is deliberately not stubbed: an install script reaching for root should
# fail this test loudly instead of being silently neutered.
for stub_name in open defaults curl git make ya aerospace osascript; do
  write_generic_stub "$stub_name"
done

cat >"$stub_dir/brew" <<'STUB'
#!/bin/sh
# Sandbox stub: record the call, install nothing, start no service.
printf 'brew %s\n' "$*" >>"${DOTFILES_STUB_LOG:-/dev/null}"
case "${1:-}" in
  list)
    # Report "not installed" so brew_install_cask runs its full decision path
    # (cask_app_paths -> cask_app_exists -> install) instead of short-circuiting.
    exit 1
    ;;
esac
exit 0
STUB
chmod +x "$stub_dir/brew"

# --- variants ---------------------------------------------------------------

# `none` means: invoke the script with no arguments at all. That is the case
# that regressed, because an empty local array is only unbound when nothing was
# passed in; any flag at all hides the bug.
variants_for_script() {
  local name="$1"
  case "$name" in
    gbrain.sh)
      # Not part of the common install-flag contract: it clones a private repo,
      # requires bun and Docker, and rejects --deploy-only by design. Only its
      # own argument parser can be exercised hermetically.
      printf '%s\n' --help
      ;;
    gui-path.sh)
      # A zero-argument run reaches `/bin/launchctl setenv PATH`. That absolute
      # path cannot be intercepted by a PATH stub, so the run would mutate the
      # real GUI login session. --deploy-only keeps DOTFILES_INSTALL=0 and stays
      # inside the sandbox.
      printf '%s\n' --help
      printf '%s\n' --deploy-only
      ;;
    *)
      printf '%s\n' --help
      printf '%s\n' --deploy-only
      printf '%s\n' none
      ;;
  esac
}

# --- runner -----------------------------------------------------------------

runs=0
failures=0
failure_list=""

record_failure() {
  local rel="$1"
  local label="$2"
  local reason="$3"
  local output_file="$4"

  failures=$((failures + 1))
  failure_list="${failure_list}  ${rel} ${label}: ${reason}"$'\n'

  printf 'FAIL: %s %s: %s\n' "$rel" "$label" "$reason" >&2
  printf -- '--- last 20 lines of output ---\n' >&2
  tail -n 20 "$output_file" >&2
  if [[ -s "$stub_log" ]]; then
    printf -- '--- stubbed commands during this run (last 15) ---\n' >&2
    tail -n 15 "$stub_log" >&2
  fi
  printf -- '-------------------------------\n' >&2
}

run_install_script() {
  local script="$1"
  local variant="$2"
  local rel="${script#"$repo_root/"}"
  local label sandbox_home output_file status
  local -a command_line

  if [[ "$variant" == "none" ]]; then
    label='(no arguments)'
  else
    label="$variant"
  fi

  sandbox_home="$(mktemp -d "$sandbox_root/home.XXXXXX")"
  output_file="$(mktemp "$sandbox_root/output.XXXXXX")"
  runs=$((runs + 1))

  # Drop every environment variable the install scripts read as an override, so
  # the sandbox cannot leak into the developer's real directories.
  command_line=(env
    -u AI_ROUTER_HOME
    -u BORDERS_START_SERVICE
    -u SBARLUA_CACHE_DIR
    -u SBARLUA_INSTALL_DIR
    -u SBARLUA_REF
    -u SBARLUA_REPO
    -u XDG_CACHE_HOME
    -u XDG_CONFIG_HOME
    -u XDG_DATA_HOME
    -u XDG_STATE_HOME
    "HOME=$sandbox_home"
    "PATH=$stub_dir:$PATH"
    "DOTFILES_STUB_LOG=$stub_log"
    "$system_bash"
    "$script"
  )

  if [[ "$variant" != "none" ]]; then
    command_line+=("$variant")
  fi

  status=0
  : >"$stub_log"
  "${command_line[@]}" >"$output_file" 2>&1 || status=$?

  if [[ "$status" -ne 0 ]]; then
    record_failure "$rel" "$label" "exited $status, expected 0" "$output_file"
    rm -rf "$sandbox_home"
    return 0
  fi

  # A deploy run that writes nothing would pass every exit-code assertion while
  # doing no work at all, so require evidence that config actually landed.
  if [[ "$variant" == "--deploy-only" && -z "$(ls -A "$sandbox_home" 2>/dev/null)" ]]; then
    record_failure "$rel" "$label" 'deployed nothing into the isolated HOME' "$output_file"
  fi

  rm -rf "$sandbox_home"
}

while IFS= read -r script; do
  script_name="${script##*/}"
  variants="$(variants_for_script "$script_name")"
  for variant in $variants; do
    run_install_script "$script" "$variant"
  done
done < <(find "$repo_root/bootstrap/install" -type f -name '*.sh' | sort)

if [[ "$runs" -eq 0 ]]; then
  printf 'No install scripts were executed; the test found nothing to run.\n' >&2
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  printf '\ninstall_deploy_smoke.sh: %s of %s runs failed\n' "$failures" "$runs" >&2
  printf '%s' "$failure_list" >&2
  exit 1
fi

printf 'install_deploy_smoke.sh: ok (%s runs on bash %s)\n' "$runs" "$system_bash_version"
