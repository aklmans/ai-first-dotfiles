#!/usr/bin/env bash
set -euo pipefail

# Covers bootstrap/setup.sh, the layer that drives the module scripts.
#
# Why this exists: setup.sh runs sixteen independent modules under `set -e`, so
# the first non-zero exit used to end the whole run. That is not theoretical -
# `brew services restart sketchybar` failed on a real machine because of an
# untrusted tap, and borders, Hammerspoon, the AI router and mpv were never
# reached. The user saw one error from the middle of the list and had no way to
# tell what had been installed. So the properties pinned down here are:
#
#   1. A failing module does not stop the modules after it, is named in a report
#      at the end, and makes the run exit non-zero.
#   2. Exit code 3 - "paths were left untouched, nothing was overwritten" - is
#      reported as a skip, not as a failure, and still exits 0.
#   3. --deploy-only deploys and nothing else: no app launched, no macOS default
#      written, no brew service restarted.
#   4. --dry-run names the paths under $HOME that would be written.
#   5. Legacy profiles stay compatible while new installs expose honest,
#      composable modules and presets.
#
# Everything that would touch the machine (brew, open, defaults, curl, git,
# make, ya) is stubbed on PATH, HOME is a throwaway directory, and setup.sh runs
# on /bin/bash so bash 3.2 regressions cannot hide.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
setup_sh="$repo_root/bootstrap/setup.sh"
system_bash="/bin/bash"

# --- setup.sh must be exercised on bash 3.2, not Homebrew's bash 5 -----------

if [[ ! -x "$system_bash" ]]; then
  printf 'Missing %s; setup.sh must be tested on the macOS system bash.\n' "$system_bash" >&2
  exit 1
fi

system_bash_version="$("$system_bash" -c 'printf "%s\n" "$BASH_VERSION"')"
case "$system_bash_version" in
  3.2.*)
    ;;
  *)
    printf 'Expected %s to be bash 3.2, got %s.\n' "$system_bash" "$system_bash_version" >&2
    exit 1
    ;;
esac

# --- sandbox ----------------------------------------------------------------

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/orchestration-smoke.XXXXXX")"
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

for stub_name in open defaults curl git make ya aerospace osascript; do
  write_generic_stub "$stub_name"
done

# The failure injection point. DOTFILES_STUB_BREW_FAIL holds a substring of a
# brew command line that should fail, which is how a module is made to fail
# without editing any tracked file: `install lua` makes sketchybar.sh die on its
# `brew_install lua switchaudio-osx ... sketchybar` line, exactly where the real
# untrusted-tap failure hit.
cat >"$stub_dir/brew" <<'STUB'
#!/bin/sh
printf 'brew %s\n' "$*" >>"${DOTFILES_STUB_LOG:-/dev/null}"

if [ -n "${DOTFILES_STUB_BREW_FAIL:-}" ]; then
  case "$*" in
    *"$DOTFILES_STUB_BREW_FAIL"*)
      printf 'brew: simulated failure for `brew %s`\n' "$*" >&2
      exit 1
      ;;
  esac
fi

# Stands in for the user pressing Ctrl-C in the middle of a module.
if [ -n "${DOTFILES_STUB_BREW_SIGNAL:-}" ]; then
  case "$*" in
    *"$DOTFILES_STUB_BREW_SIGNAL"*)
      kill -INT $$
      ;;
  esac
fi

case "${1:-}" in
  list)
    # Report "not installed" so brew_install_cask runs its full decision path.
    exit 1
    ;;
  trust)
    # Homebrew 6 answers "which third-party taps may I load from" here.
    # DOTFILES_STUB_BREW_TRUSTED is a JSON array body, so a case can hand back
    # either an empty trust list or one that already contains the tap.
    printf '{"taps":[%s],"formulae":[],"casks":[],"commands":[]}\n' \
      "${DOTFILES_STUB_BREW_TRUSTED:-}"
    exit 0
    ;;
esac
exit 0
STUB
chmod +x "$stub_dir/brew"

# --- assertions -------------------------------------------------------------

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

assert_exists() {
  if [[ -e "$1" || -L "$1" ]]; then
    pass
  else
    fail "$2" "missing path: $1"
  fi
}

assert_missing() {
  if [[ -e "$1" || -L "$1" ]]; then
    fail "$2" "path should not exist: $1"
  else
    pass
  fi
}

assert_equal() {
  if [[ "$1" == "$2" ]]; then
    pass
  else
    fail "$3" "expected: $1
actual:   $2"
  fi
}

assert_nonzero_status() {
  if [[ "$1" -ne 0 ]]; then
    pass
  else
    fail "$2" "$3"
  fi
}

assert_output_matches() {
  if printf '%s\n' "$1" | grep -Eq "$2"; then
    pass
  else
    fail "$3" "$1"
  fi
}

assert_output_lacks() {
  if printf '%s\n' "$1" | grep -Eq "$2"; then
    fail "$3" "$1"
  else
    pass
  fi
}

assert_file_lacks() {
  if grep -Eq "$2" "$1" 2>/dev/null; then
    fail "$3" "$(cat "$1" 2>/dev/null || true)"
  else
    pass
  fi
}

# --- runner -----------------------------------------------------------------

RUN_ENV=()
last_output=""
last_status=0

run_setup() {
  local home_dir="$1"
  shift

  : >"$stub_log"
  last_status=0
  last_output="$(env \
    -u AI_ROUTER_HOME \
    -u BORDERS_START_SERVICE \
    -u DOTFILES_FORCE \
    -u DOTFILES_STUB_BREW_FAIL \
    -u DOTFILES_STUB_BREW_SIGNAL \
    -u DOTFILES_STUB_BREW_TRUSTED \
    -u SBARLUA_CACHE_DIR \
    -u SBARLUA_INSTALL_DIR \
    -u XDG_CACHE_HOME \
    -u XDG_CONFIG_HOME \
    -u XDG_DATA_HOME \
    -u XDG_STATE_HOME \
    ${RUN_ENV[@]+"${RUN_ENV[@]}"} \
    "HOME=$home_dir" \
    "PATH=$stub_dir:$PATH" \
    "DOTFILES_STUB_LOG=$stub_log" \
    "DOTFILES_SKIP_PREFLIGHT=1" \
    "$system_bash" "$setup_sh" "$@" 2>&1)" || last_status=$?
  RUN_ENV=()
}

new_home() {
  mktemp -d "$sandbox_root/home.XXXXXX"
}

# --- case: one failing module does not take the run with it -----------------
# The reason this file exists. sketchybar.sh dies on its brew line, which is
# where the real-world failure hit, and everything after it must still run.

case_failure_does_not_stop_the_run() {
  local home
  home="$(new_home)"

  RUN_ENV=("DOTFILES_STUB_BREW_FAIL=install lua")
  run_setup "$home" desktop

  assert_nonzero_status "$last_status" \
    'a failed module must make the whole run exit non-zero' "$last_output"

  # The module that failed did not get as far as deploying its config...
  assert_missing "$home/.config/sketchybar" 'the failing module must not have deployed'

  # ...and every module after it still ran.
  assert_exists "$home/.config/borders" 'the module after the failure must still run'
  assert_exists "$home/.hammerspoon" 'later modules must still run'
  # As did the ones before it.
  assert_exists "$home/.config/karabiner" 'modules before the failure must still run'
  assert_exists "$home/.aerospace.toml" 'modules before the failure must still run'

  assert_output_matches "$last_output" 'step\(s\) failed' \
    'a run with a failure must end with a failure report'
  assert_output_matches "$last_output" 'install/sketchybar\.sh' \
    'the failure report must name the module that failed'
  assert_output_matches "$last_output" 'exit 1' \
    'the failure report must include the exit code'
}

# --- case: an untrusted third-party tap explains itself ----------------------
# Homebrew 6 refuses to install from a third-party tap until it is trusted, and
# it refuses even for a formula that is already installed. A fresh Mac therefore
# lost half of `minimal` - workspace + bar, with bar failing - to brew's own
# error printed a screen above the run summary, and nothing said what to do.
#
# Trust state alone must not be what triggers the guidance: these taps are
# untrusted on the maintainer's machine too, where plenty installs fine. Only a
# real install failure may produce it.

case_untrusted_tap_is_explained() {
  local home
  home="$(new_home)"

  RUN_ENV=("DOTFILES_STUB_BREW_FAIL=install lua" "DOTFILES_STUB_BREW_TRUSTED=")
  run_setup "$home" bar

  assert_nonzero_status "$last_status" 'the failing module must still fail' "$last_output"
  assert_output_matches "$last_output" 'brew trust felixkratz/formulae' \
    'a failed install from an untrusted tap must name the exact trust command'
  assert_output_matches "$last_output" 'lets its code run on this machine' \
    'the guidance must say what trusting a tap means, not just how to do it'
  assert_output_matches "$last_output" 'safe to run again' \
    'the guidance must say the run can simply be repeated'

  # Trusted already: the same failure must not blame trust for it.
  home="$(new_home)"
  RUN_ENV=("DOTFILES_STUB_BREW_FAIL=install lua" 'DOTFILES_STUB_BREW_TRUSTED="felixkratz/formulae"')
  run_setup "$home" bar

  assert_nonzero_status "$last_status" 'the failing module must still fail' "$last_output"
  assert_output_lacks "$last_output" 'brew trust' \
    'a failure on a trusted tap must not suggest trusting it'

  # Nothing failed at all: the guidance must stay out of a clean run.
  home="$(new_home)"
  RUN_ENV=("DOTFILES_STUB_BREW_TRUSTED=")
  run_setup "$home" bar

  assert_output_lacks "$last_output" 'brew trust' \
    'a successful run must never mention trusting a tap'
}

# --- case: Ctrl-C stops the run ---------------------------------------------
# Tolerating failures must not turn an interruption into "install another dozen
# things". `cmd || status=$?` swallows the signal that used to end the script,
# so setup.sh has to notice it itself.

case_interrupted_step_stops_the_run() {
  local home
  home="$(new_home)"

  RUN_ENV=("DOTFILES_STUB_BREW_SIGNAL=install lua")
  run_setup "$home" desktop

  assert_equal 130 "$last_status" 'an interrupted run must exit with the signal status'
  assert_output_matches "$last_output" 'interrupted' 'an interrupted run must say why it stopped'
  assert_missing "$home/.config/borders" 'nothing after an interruption may run'
  assert_missing "$home/.hammerspoon" 'nothing after an interruption may run'
  assert_exists "$home/.config/karabiner" 'what ran before the interruption stays'
}

# --- case: a skip is not a failure ------------------------------------------
# Exit code 3 means the deploy engine refused to touch paths another tool owns.
# Nothing was overwritten, so the run is still a success.

case_skip_alone_is_not_a_failure() {
  local home
  home="$(new_home)"
  ln -sfn /tmp/managed-elsewhere "$home/.hammerspoon"

  run_setup "$home" desktop

  assert_equal 0 "$last_status" 'a skipped path must not fail the run'
  assert_output_matches "$last_output" 'left some paths untouched' \
    'a skipped path must be reported'
  assert_output_lacks "$last_output" 'step\(s\) failed' \
    'a skip must not be reported as a failure'

  if [[ -L "$home/.hammerspoon" ]]; then
    pass
  else
    fail 'the symlink must survive the run'
  fi
  assert_exists "$home/.config/sketchybar" 'modules around the skip must still deploy'
}

# --- case: skips and failures are reported apart ----------------------------

case_skip_and_failure_are_reported_apart() {
  local home
  home="$(new_home)"
  ln -sfn /tmp/managed-elsewhere "$home/.hammerspoon"

  RUN_ENV=("DOTFILES_STUB_BREW_FAIL=install lua")
  run_setup "$home" desktop

  assert_nonzero_status "$last_status" \
    'a failure alongside a skip must still exit non-zero' "$last_output"
  assert_output_matches "$last_output" 'left some paths untouched' \
    'the skip must still be reported when something else failed'
  assert_output_matches "$last_output" 'step\(s\) failed' \
    'the failure must be reported alongside the skip'
  assert_output_matches "$last_output" 'install/sketchybar\.sh' \
    'the failure report must name the module that failed'
  assert_output_lacks "$last_output" '\- .*install/hammerspoon\.sh' \
    'a skipped module must not appear in the failure list'
}

# --- case: --deploy-only deploys and does nothing else ----------------------
# The flag is documented as "deploy config only", but it used to write a global
# macOS default, launch two apps and restart a brew service.

case_deploy_only_is_inert() {
  local home
  home="$(new_home)"

  run_setup "$home" deploy

  # Evidence the run did real work, so the assertions below are not vacuous.
  assert_exists "$home/.config/ai-router" 'deploy must actually deploy config'
  assert_exists "$home/.config/karabiner" 'deploy must actually deploy config'

  assert_file_lacks "$stub_log" '^open ' \
    '--deploy-only must not launch any app'
  assert_file_lacks "$stub_log" '^defaults ' \
    '--deploy-only must not write any macOS default'
  assert_file_lacks "$stub_log" 'brew services' \
    '--deploy-only must not touch brew services'
  assert_file_lacks "$stub_log" '^brew install' \
    '--deploy-only must not install packages'
}

# --- case: --dry-run says which paths would be written ----------------------

case_dry_run_names_target_paths() {
  local home
  home="$(new_home)"

  run_setup "$home" ai --dry-run
  assert_equal 0 "$last_status" 'a dry run should succeed'
  assert_output_matches "$last_output" "$home/\.config/ai-router" \
    'a dry run must name the path it would write'
  assert_output_matches "$last_output" 'new;.*files from home/\.config/ai-router' \
    'a dry run must say what would land there and where it comes from'

  run_setup "$home" desktop --dry-run
  assert_output_matches "$last_output" "$home/\.config/sketchybar" \
    'a dry run must name every module target'
  assert_output_matches "$last_output" "$home/\.hammerspoon" \
    'a dry run must name every module target'
  assert_output_matches "$last_output" "$home/\.aerospace\.toml" \
    'a dry run must name single-file targets too'

  # borders.sh names its target through a variable, so the preview has to
  # resolve one instead of printing "$target_path" at the reader.
  assert_output_matches "$last_output" "$home/\.config/borders" \
    'a dry run must resolve a target named through a variable'
  assert_output_lacks "$last_output" '\$[A-Za-z_]' \
    'a dry run must not print unresolved shell variables as paths'

  run_setup "$home" gui-path --dry-run
  assert_output_matches "$last_output" "$home/Library/LaunchAgents/com\.ai-first-dotfiles\.gui-path\.plist" \
    'a dry run must resolve a target named through a variable'

  # sublime.sh wraps its deploy calls across several lines; the preview has to
  # read those as well as the single-line form.
  run_setup "$home" sublime --dry-run
  assert_output_matches "$last_output" 'Sublime Text/Packages/User/gui_path\.py' \
    'a dry run must read deploy calls that wrap across lines'

  # And a preview must remain a preview.
  assert_equal '' "$(ls -A "$home" 2>/dev/null || true)" 'a dry run must write nothing'
  assert_equal '' "$(cat "$stub_log" 2>/dev/null || true)" 'a dry run must run no command'
}

# --- case: the opt-in layers are opt-in -------------------------------------
# Hijacking ~/.zshenv and installing a paid app are both things a stranger has
# to ask for; `all` is the line README tells them to run.

case_all_excludes_opt_in_layers() {
  local home
  home="$(new_home)"

  run_setup "$home" all --dry-run
  assert_equal 0 "$last_status" 'the all dry run should succeed'
  assert_output_lacks "$last_output" 'install/zsh\.sh' \
    'the shell layer must not be part of all'
  assert_output_lacks "$last_output" 'install/bettertouchtool\.sh' \
    'BetterTouchTool is paid after 45 days and must not be part of all'
  assert_output_lacks "$last_output" 'install/warp\.sh' \
    'Warp is closed source and must not be part of all'
  assert_output_matches "$last_output" 'install/sketchybar\.sh' \
    'all must still cover the desktop layer'
  assert_output_matches "$last_output" 'install/ai-router\.sh' \
    'all must still cover the AI router'

  run_setup "$home" shell --dry-run
  assert_output_matches "$last_output" 'install/zsh\.sh' \
    'the shell layer must still be reachable on request'

  run_setup "$home" extras --dry-run
  assert_output_matches "$last_output" 'install/bettertouchtool\.sh' \
    'extras must cover BetterTouchTool'
  assert_output_matches "$last_output" 'install/warp\.sh' \
    'extras must cover Warp'

  # Deploying installs nothing, so it still covers every tracked config.
  run_setup "$home" deploy --dry-run
  assert_output_matches "$last_output" 'install/zsh\.sh' \
    'deploy must still cover the config of the opt-in layers'
  assert_output_matches "$last_output" 'install/warp\.sh' \
    'deploy must still cover the config of the opt-in layers'

  # The help text is where a stranger looks for this, so it has to say it.
  run_setup "$home" --help
  assert_output_matches "$last_output" 'extras' 'usage must document the extras profile'
  assert_output_matches "$last_output" 'author-full.*paid/closed' \
    'usage must label the complete opinionated preset honestly'
}

# --- case: choice architecture is safe before installation ------------------

case_choices_are_visible_and_no_arg_is_inert() {
  local home
  home="$(new_home)"

  run_setup "$home"
  assert_equal 0 "$last_status" 'no-argument setup should succeed'
  assert_output_matches "$last_output" 'Modules \(combine as needed\)' \
    'no-argument setup must show composable choices'
  assert_output_matches "$last_output" 'minimal.*small, free desktop starting point' \
    'no-argument setup must show the small starting preset'
  assert_equal '' "$(ls -A "$home" 2>/dev/null || true)" \
    'no-argument setup must change nothing'
  assert_equal '' "$(cat "$stub_log" 2>/dev/null || true)" \
    'no-argument setup must execute nothing'

  run_setup "$home" minimal --dry-run
  assert_equal 0 "$last_status" 'minimal dry-run should succeed'
  assert_output_matches "$last_output" 'cask[[:space:]]+nikitabobko/tap/aerospace|cask[[:space:]]+aerospace' \
    'minimal preview must name the AeroSpace package'
  assert_output_matches "$last_output" 'formula[[:space:]]+sketchybar' \
    'minimal preview must name the SketchyBar package'
  assert_output_lacks "$last_output" 'bettertouchtool|install/warp\.sh|install/zsh\.sh' \
    'minimal preview must not smuggle in paid, closed, or shell choices'
  assert_output_matches "$last_output" '\.config/ai-first/profile\.conf' \
    'a preset preview must name its runtime preference file'
}

# --- run --------------------------------------------------------------------

case_failure_does_not_stop_the_run
case_untrusted_tap_is_explained
case_interrupted_step_stops_the_run
case_skip_alone_is_not_a_failure
case_skip_and_failure_are_reported_apart
case_deploy_only_is_inert
case_dry_run_names_target_paths
case_all_excludes_opt_in_layers
case_choices_are_visible_and_no_arg_is_inert

if [[ "$failures" -gt 0 ]]; then
  printf '\norchestration_smoke.sh: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi

printf 'orchestration_smoke.sh: ok (%s checks on bash %s)\n' "$checks" "$system_bash_version"
