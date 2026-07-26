#!/usr/bin/env bash
set -euo pipefail

# Covers the shell layer: bootstrap/install/zsh.sh and the config it deploys
# into ~/.config/zsh.
#
# Why this exists:
#
#   1. Deploying ~/.zshenv points ZDOTDIR at ~/.config/zsh, and from the next
#      shell on zsh never opens ~/.zshrc again. The old file stays on disk,
#      untouched and unread, with nothing anywhere to explain why the user's
#      shell configuration stopped applying. That used to happen silently.
#   2. The deployed config carried one machine's private environment: a proxy
#      port, package-manager mirrors that silently redirect every Go and Flutter
#      download, launcher aliases for scripts this repo does not ship, and two
#      `ls` aliases that cannot run on a stock macOS at all.
#
# Every run here uses a throwaway HOME, runs the script under /bin/bash (bash
# 3.2, what macOS ships) and puts a hard time limit on it: a confirmation
# prompt that blocks a non-interactive run is a hang, and a hanging test is
# worse than a failing one.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
zsh_install="$repo_root/bootstrap/install/zsh.sh"
repo_zsh_dir="$repo_root/home/.config/zsh"
system_bash="/bin/bash"
system_zsh="/bin/zsh"

# --- the script must be exercised on bash 3.2, not Homebrew's bash 5 ---------

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
    exit 1
    ;;
esac

# --- sandbox ----------------------------------------------------------------

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/shell-layer-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

stub_dir="$sandbox_root/stub-bin"
stub_log="$sandbox_root/stub-calls.log"
mkdir -p "$stub_dir"
: >"$stub_log"

for stub_name in open defaults curl git make ya aerospace osascript; do
  cat >"$stub_dir/$stub_name" <<'STUB'
#!/bin/sh
# Sandbox stub: record the call, succeed, touch nothing outside the sandbox.
printf '%s %s\n' "${0##*/}" "$*" >>"${DOTFILES_STUB_LOG:-/dev/null}"
exit 0
STUB
  chmod +x "$stub_dir/$stub_name"
done

cat >"$stub_dir/brew" <<'STUB'
#!/bin/sh
printf 'brew %s\n' "$*" >>"${DOTFILES_STUB_LOG:-/dev/null}"
case "${1:-}" in
  list)
    exit 1
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

assert_output_matches() {
  if printf '%s\n' "$1" | grep -Eqi -- "$2"; then
    pass
  else
    fail "$3" "$1"
  fi
}

assert_output_lacks() {
  if printf '%s\n' "$1" | grep -Eqi -- "$2"; then
    fail "$3" "$1"
  else
    pass
  fi
}

# --- runner -----------------------------------------------------------------
#
# Nothing here may wait on a terminal, so every run is killed after a fixed
# number of seconds and the timeout is reported as its own failure.

RUN_ENV=()
last_output=""
last_status=0
last_timed_out=0

run_home() {
  local home_dir="$1"
  shift

  local out_file pid ticks=0 limit_ticks=150

  out_file="$(mktemp "$sandbox_root/output.XXXXXX")"
  last_status=0
  last_timed_out=0

  env \
    -u AI_ROUTER_HOME \
    -u DOTFILES_FORCE \
    -u XDG_CACHE_HOME \
    -u XDG_CONFIG_HOME \
    -u XDG_DATA_HOME \
    -u XDG_STATE_HOME \
    ${RUN_ENV[@]+"${RUN_ENV[@]}"} \
    "HOME=$home_dir" \
    "PATH=$stub_dir:$PATH" \
    "DOTFILES_STUB_LOG=$stub_log" \
    "$system_bash" "$@" >"$out_file" 2>&1 </dev/null &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    if [[ "$ticks" -ge "$limit_ticks" ]]; then
      kill -9 "$pid" 2>/dev/null || true
      last_timed_out=1
      break
    fi
    sleep 0.2
    ticks=$((ticks + 1))
  done

  wait "$pid" 2>/dev/null || last_status=$?
  last_output="$(cat "$out_file" 2>/dev/null || true)"
  rm -f "$out_file"
  RUN_ENV=()
}

# Runs the script attached to a pseudo terminal, so the interactive branch is
# reached, and answers the prompt with $2. This is the only way to prove the
# confirmation actually gates the takeover rather than being decoration.
run_home_interactive() {
  local home_dir="$1"
  local answer="$2"
  shift 2

  local out_file pid ticks=0 limit_ticks=150

  out_file="$(mktemp "$sandbox_root/output.XXXXXX")"
  last_status=0
  last_timed_out=0

  { sleep 1; printf '%s\n' "$answer"; sleep 1; } |
    script -q /dev/null env \
      -u DOTFILES_FORCE \
      -u XDG_STATE_HOME \
      "HOME=$home_dir" \
      "PATH=$stub_dir:$PATH" \
      "$system_bash" "$@" >"$out_file" 2>&1 &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    if [[ "$ticks" -ge "$limit_ticks" ]]; then
      kill -9 "$pid" 2>/dev/null || true
      last_timed_out=1
      break
    fi
    sleep 0.2
    ticks=$((ticks + 1))
  done

  wait "$pid" 2>/dev/null || last_status=$?
  last_output="$(cat "$out_file" 2>/dev/null || true)"
  rm -f "$out_file"
}

# Starts a real interactive zsh on the deployed config, with an empty
# environment and a PATH that holds nothing but the system tools - a Mac where
# none of the packages this repo installs exist yet.
run_zsh_snippet() {
  local home_dir="$1"
  local snippet="$2"

  local out_file pid ticks=0 limit_ticks=150

  out_file="$(mktemp "$sandbox_root/zsh-out.XXXXXX")"
  last_status=0
  last_timed_out=0

  env -i \
    "HOME=$home_dir" \
    'TERM=xterm' \
    'PATH=/usr/bin:/bin:/usr/sbin:/sbin' \
    "$system_zsh" -i -c "$snippet" >"$out_file" 2>&1 </dev/null &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    if [[ "$ticks" -ge "$limit_ticks" ]]; then
      kill -9 "$pid" 2>/dev/null || true
      last_timed_out=1
      break
    fi
    sleep 0.2
    ticks=$((ticks + 1))
  done

  wait "$pid" 2>/dev/null || last_status=$?
  last_output="$(cat "$out_file" 2>/dev/null || true)"
  rm -f "$out_file"
}

new_home() {
  mktemp -d "$sandbox_root/home.XXXXXX"
}

home_with_zshrc() {
  local home_dir
  home_dir="$(new_home)"
  printf 'export MY_OWN_THING=1\n' >"$home_dir/.zshrc"
  printf '%s\n' "$home_dir"
}

assert_not_timed_out() {
  if [[ "$last_timed_out" -eq 1 ]]; then
    fail "$1" "the run was killed after 30s; it was waiting for something"
  else
    pass
  fi
}

# --- case: an existing ~/.zshrc is never hijacked silently -------------------
# The reason this file exists. Everything else here is secondary to it.

case_existing_zshrc_is_not_hijacked() {
  local home
  home="$(home_with_zshrc)"

  run_home "$home" "$zsh_install" --deploy-only
  assert_not_timed_out 'a deploy over an existing ~/.zshrc must not wait for input'

  assert_output_matches "$last_output" 'zshrc' \
    'the user must be told their ~/.zshrc is involved'
  assert_output_matches "$last_output" 'ZDOTDIR' \
    'the warning must name the mechanism that takes over'
  assert_output_matches "$last_output" 'stops? (your |running|loading)|never opens' \
    'the warning must say what actually happens to ~/.zshrc'

  assert_missing "$home/.zshenv" \
    'without a yes, ~/.zshenv must not be deployed'
  assert_equal 'export MY_OWN_THING=1' "$(cat "$home/.zshrc" 2>/dev/null || true)" \
    'the user ~/.zshrc must never be edited or moved'
  assert_exists "$home/.config/zsh/.zshrc.pre-dotfiles" \
    'a copy of the pre-existing ~/.zshrc must be findable under ZDOTDIR'
  assert_equal 'export MY_OWN_THING=1' \
    "$(cat "$home/.config/zsh/.zshrc.pre-dotfiles" 2>/dev/null || true)" \
    'the rescue copy must hold the original content'

  # Refusing the redirect is a report, not a crash: exit 3 is what setup.sh
  # already reads as "some paths were left untouched".
  assert_equal 3 "$last_status" \
    'declining the takeover must exit 3, not 0 and not a hard failure'

  # The rest of the config is inert without ZDOTDIR, so it still lands and the
  # follow-up --force run has nothing left to do but the one file.
  assert_exists "$home/.config/zsh/aliases.zsh" \
    'the rest of the shell config must still deploy'
}

# --- case: a run with no terminal must never block --------------------------

case_non_interactive_never_blocks() {
  local home

  home="$(home_with_zshrc)"
  run_home "$home" "$zsh_install" --deploy-only
  assert_not_timed_out 'stdin on /dev/null must not block the deploy'

  # setup.sh deploy reaches the same script through another layer.
  home="$(home_with_zshrc)"
  RUN_ENV=("DOTFILES_SKIP_PREFLIGHT=1")
  run_home "$home" "$repo_root/bootstrap/setup.sh" shell
  assert_not_timed_out 'a full shell profile run must not block on the prompt'
  assert_missing "$home/.zshenv" 'setup.sh must not hand the shell over unasked either'
}

# --- case: --force and DOTFILES_FORCE=1 are the way to say yes upfront ------

case_force_takes_over() {
  local home

  home="$(home_with_zshrc)"
  run_home "$home" "$zsh_install" --deploy-only --force
  assert_not_timed_out '--force must not wait for input'
  assert_equal 0 "$last_status" '--force must complete normally'
  assert_exists "$home/.zshenv" '--force must deploy ~/.zshenv'
  assert_output_matches "$last_output" 'zshrc' \
    '--force must still explain what it did'
  assert_equal 'export MY_OWN_THING=1' "$(cat "$home/.zshrc" 2>/dev/null || true)" \
    '--force must still leave the original ~/.zshrc alone'
  assert_exists "$home/.config/zsh/.zshrc.pre-dotfiles" \
    '--force must still leave the rescue copy behind'

  home="$(home_with_zshrc)"
  RUN_ENV=("DOTFILES_FORCE=1")
  run_home "$home" "$zsh_install" --deploy-only
  assert_not_timed_out 'DOTFILES_FORCE=1 must not wait for input'
  assert_equal 0 "$last_status" 'DOTFILES_FORCE=1 must behave like --force'
  assert_exists "$home/.zshenv" 'DOTFILES_FORCE=1 must deploy ~/.zshenv'
}

# --- case: a HOME with no ~/.zshrc deploys quietly --------------------------

case_clean_home_is_quiet() {
  local home
  home="$(new_home)"

  run_home "$home" "$zsh_install" --deploy-only
  assert_not_timed_out 'a clean HOME must not wait for input'
  assert_equal 0 "$last_status" 'a clean HOME must deploy normally'
  assert_exists "$home/.zshenv" 'a clean HOME must get ~/.zshenv'
  assert_output_lacks "$last_output" 'WARNING' \
    'there is nothing to warn about when there is no ~/.zshrc'
  assert_missing "$home/.config/zsh/.zshrc.pre-dotfiles" \
    'no ~/.zshrc means no rescue copy to make'
}

# --- case: the second deploy does not re-ask --------------------------------
# The upgrade path. Anyone who deployed an earlier version already has ~/.zshenv
# redirecting ZDOTDIR, and may still have the ~/.zshrc it silenced. Asking again
# every time would train people to skip the text; saying nothing would leave the
# orphaned file unexplained. So: rescue copy once, note once, never a prompt.

case_redeploy_does_not_re_ask() {
  local home
  home="$(home_with_zshrc)"
  printf 'export ZDOTDIR="$HOME/.config/zsh"\n' >"$home/.zshenv"

  run_home "$home" "$zsh_install" --deploy-only
  assert_not_timed_out 'a redeploy must not wait for input'
  assert_equal 0 "$last_status" 'an already-redirected HOME must deploy normally'
  assert_output_lacks "$last_output" 'WARNING' \
    'the takeover already happened; there is no new consequence to warn about'
  assert_exists "$home/.config/zsh/.zshrc.pre-dotfiles" \
    'the already-silenced ~/.zshrc must still be made findable'
  assert_output_matches "$last_output" 'out of the loop' \
    'the orphaned ~/.zshrc must be explained once'

  printf 'changed by hand\n' >"$home/.config/zsh/.zshrc.pre-dotfiles"
  run_home "$home" "$zsh_install" --deploy-only
  assert_output_lacks "$last_output" 'out of the loop' \
    'the note must not repeat on every deploy'
  assert_equal 'changed by hand' "$(cat "$home/.config/zsh/.zshrc.pre-dotfiles" 2>/dev/null || true)" \
    'the rescue copy is the user file; a later run must not rewrite it'
}

# --- case: the prompt actually gates the takeover ---------------------------

case_prompt_gates_the_takeover() {
  local home

  if ! command -v script >/dev/null 2>&1; then
    fail 'script(1) is required to exercise the interactive branch'
    return 0
  fi

  home="$(home_with_zshrc)"
  run_home_interactive "$home" 'n' "$zsh_install" --deploy-only
  assert_not_timed_out 'answering the prompt must end the run'
  assert_output_matches "$last_output" 'Hand zsh startup over' \
    'an interactive run must actually ask'
  assert_missing "$home/.zshenv" 'answering no must leave ~/.zshenv alone'

  home="$(home_with_zshrc)"
  run_home_interactive "$home" 'y' "$zsh_install" --deploy-only
  assert_not_timed_out 'answering yes must end the run'
  assert_equal 0 "$last_status" 'answering yes must complete normally'
  assert_exists "$home/.zshenv" 'answering yes must deploy ~/.zshenv'
}

# --- case: uninstall never takes the user's own files with it ---------------

case_uninstall_keeps_the_rescue_copy() {
  local home
  home="$(home_with_zshrc)"

  run_home "$home" "$zsh_install" --deploy-only --force
  assert_exists "$home/.config/zsh/.zshrc.pre-dotfiles" 'setup for the rollback'

  run_home "$home" "$repo_root/bootstrap/uninstall.sh" --files-only --apply
  assert_equal 0 "$last_status" 'uninstall --apply should succeed'
  assert_equal 'export MY_OWN_THING=1' "$(cat "$home/.zshrc" 2>/dev/null || true)" \
    'uninstall must not touch the original ~/.zshrc'
  assert_exists "$home/.config/zsh/.zshrc.pre-dotfiles" \
    'uninstall must not delete the rescue copy: it is the user'"'"'s own file'
  assert_missing "$home/.zshenv" 'uninstall must still remove what this repo deployed'
}

# --- case: no private environment in the deployed config --------------------
# Each pattern below was in a file this repo deployed to every user.

case_no_private_environment() {
  local home hits
  local -a patterns

  patterns=(
    '7890'
    'goproxy\.cn'
    'flutter-io\.cn'
    '\.jetbrains'
    'kiro-cli'
    'ls --all'
    'ls --tree'
    'AI_PROVIDER'
    'AI_MODEL'
  )

  # In the repo, where the review can see it...
  for pattern in ${patterns[@]+"${patterns[@]}"}; do
    hits="$(grep -REn -- "$pattern" "$repo_zsh_dir" 2>/dev/null | grep -v '\.example:' || true)"
    if [[ -n "$hits" ]]; then
      fail "private environment still in the tracked zsh config: $pattern" "$hits"
    else
      pass
    fi
  done

  # ...and in what actually lands in a user's HOME.
  home="$(new_home)"
  run_home "$home" "$zsh_install" --deploy-only
  for pattern in ${patterns[@]+"${patterns[@]}"}; do
    hits="$(grep -REn -- "$pattern" "$home/.config/zsh" 2>/dev/null | grep -v '\.example:' || true)"
    if [[ -n "$hits" ]]; then
      fail "private environment deployed into HOME: $pattern" "$hits"
    else
      pass
    fi
  done

  # The `dotfiles` helper used to point at $WORKFLOW_DIR/ai-first-dotfile, a
  # path that did not exist on any machine, including the author's.
  hits="$(grep -REn -- 'WORKFLOW_DIR/ai-first-dotfile' "$repo_zsh_dir" 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    fail 'the dotfiles helper points at a path nested under the workflow directory' "$hits"
  else
    pass
  fi
}

# --- case: the listing aliases run on a stock macOS -------------------------
# `ls --all` and `ls --tree` are not BSD ls flags. Both aliases failed on every
# clean Mac, which no grep-only assertion would have caught.

case_listing_aliases_actually_run() {
  local probe_dir status=0

  if [[ ! -x "$system_zsh" ]]; then
    fail "missing $system_zsh; the deployed config is zsh"
    return 0
  fi

  probe_dir="$(mktemp -d "$sandbox_root/probe.XXXXXX")"
  printf 'x\n' >"$probe_dir/file.txt"

  # eval so alias expansion happens after aliases.zsh has been sourced.
  "$system_zsh" -f -c '
    source "$1" >/dev/null 2>&1
    cd "$2" || exit 1
    eval lsa >/dev/null 2>&1 || exit 2
    if alias lst >/dev/null 2>&1; then
      eval lst >/dev/null 2>&1 || exit 3
    fi
  ' -- "$repo_zsh_dir/aliases.zsh" "$probe_dir" || status=$?

  case "$status" in
    0)
      pass
      ;;
    2)
      fail 'the lsa alias does not run on this machine'
      ;;
    3)
      fail 'the lst alias is defined but does not run on this machine'
      ;;
    *)
      fail "sourcing aliases.zsh under zsh failed (exit $status)"
      ;;
  esac
}

# --- case: private.zsh is the override hook, and it survives updates --------

case_private_zsh_is_the_override_hook() {
  local home tracked zshrc private_line aliases_line

  # personal.zsh was tracked, empty, and deployed: anything written into it was
  # replaced by the empty copy on the next update.
  tracked="$(cd "$repo_root" && git ls-files 'home/.config/zsh/personal.zsh' 2>/dev/null || true)"
  assert_equal '' "$tracked" 'personal.zsh must not be tracked any more'
  assert_missing "$repo_zsh_dir/personal.zsh" 'personal.zsh must not be shipped any more'
  assert_exists "$repo_zsh_dir/private.zsh.example" \
    'there must be a template to copy into private.zsh'

  if grep -Fq 'personal.zsh' "$zsh_install" 2>/dev/null; then
    fail 'the installer must not deploy personal.zsh any more'
  else
    pass
  fi

  # Sourced last, so an override in it beats every file this repo ships. It used
  # to be sourced from the middle of env.zsh, before aliases and functions.
  zshrc="$repo_zsh_dir/.zshrc"
  private_line="$(grep -n 'private\.zsh' "$zshrc" | tail -n 1 | cut -d: -f1)"
  aliases_line="$(grep -n 'aliases\.zsh' "$zshrc" | tail -n 1 | cut -d: -f1)"
  if [[ -n "$private_line" && -n "$aliases_line" && "$private_line" -gt "$aliases_line" ]]; then
    pass
  else
    fail '.zshrc must source private.zsh after everything it ships'
  fi

  if grep -Fq 'private.zsh' "$repo_zsh_dir/env.zsh" && grep -Eq '^[^#]*source.*private\.zsh' "$repo_zsh_dir/env.zsh"; then
    fail 'env.zsh must not source private.zsh any more; .zshrc owns that now'
  else
    pass
  fi

  # A private.zsh that exists must never be deployed over.
  home="$(new_home)"
  run_home "$home" "$zsh_install" --deploy-only
  mkdir -p "$home/.config/zsh"
  printf 'export MINE=1\n' >"$home/.config/zsh/private.zsh"
  run_home "$home" "$zsh_install" --deploy-only --force
  assert_equal 'export MINE=1' "$(cat "$home/.config/zsh/private.zsh" 2>/dev/null || true)" \
    'not even --force may touch private.zsh: this repo does not ship it'
  assert_exists "$home/.config/zsh/private.zsh.example" 'the template must be deployed'
}

# --- case: the deployed config starts, and private.zsh wins -----------------
# Line order in .zshrc is only a proxy for the property that matters: an
# override in private.zsh has to survive everything this repo ships.

case_deployed_config_boots() {
  local home
  home="$(new_home)"

  run_home "$home" "$zsh_install" --deploy-only
  assert_equal 0 "$last_status" 'setup deploy for the boot check'

  run_zsh_snippet "$home" 'print "BOOTED"'
  assert_not_timed_out 'starting a shell on the deployed config must not hang'
  assert_output_matches "$last_output" 'BOOTED' \
    'the deployed config must start a shell on a Mac with nothing installed yet'
  assert_output_lacks "$last_output" 'command not found|parse error|no such file' \
    'starting that shell must not print errors'

  printf "alias ll='print overridden-by-private'\n" >"$home/.config/zsh/private.zsh"
  run_zsh_snippet "$home" 'alias ll'
  assert_output_matches "$last_output" 'overridden-by-private' \
    'private.zsh must be able to override what this repo ships'

  # An older deploy left personal.zsh behind. With content it still works, and
  # says where it moved; empty - which is how this repo used to ship it - it
  # must stay silent rather than nag every shell.
  printf 'export FROM_PERSONAL=1\n' >"$home/.config/zsh/personal.zsh"
  run_zsh_snippet "$home" 'print "value=${FROM_PERSONAL:-unset}"'
  assert_output_matches "$last_output" 'value=1' \
    'an existing personal.zsh with content must keep working'
  assert_output_matches "$last_output" 'no longer part of this repo' \
    'and must say where its content should move'

  : >"$home/.config/zsh/personal.zsh"
  run_zsh_snippet "$home" 'print "quiet"'
  assert_output_lacks "$last_output" 'no longer part of this repo' \
    'the empty personal.zsh this repo used to ship must not nag'
}

# --- run --------------------------------------------------------------------

case_existing_zshrc_is_not_hijacked
case_non_interactive_never_blocks
case_force_takes_over
case_clean_home_is_quiet
case_redeploy_does_not_re_ask
case_prompt_gates_the_takeover
case_uninstall_keeps_the_rescue_copy
case_no_private_environment
case_listing_aliases_actually_run
case_private_zsh_is_the_override_hook
case_deployed_config_boots

if [[ "$failures" -gt 0 ]]; then
  printf '\nshell_layer_smoke.sh: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi

printf 'shell_layer_smoke.sh: ok (%s checks on bash %s)\n' "$checks" "$system_bash_version"
