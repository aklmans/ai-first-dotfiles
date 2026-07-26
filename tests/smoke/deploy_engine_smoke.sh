#!/usr/bin/env bash
set -euo pipefail

# Covers deploy_repo_path in bootstrap/lib/common.sh, the only code here that
# writes into a user's $HOME, plus bootstrap/uninstall.sh which rolls it back.
#
# Why this exists: deploying a directory used to mean "move the whole target
# aside and cp -R the repo copy in". Every redeploy therefore threw away the
# user's own prompts, SketchyBar items and router state, left another full
# backup copy behind, and replaced symlinks other dotfiles managers own with
# plain files. Those four properties are what the cases below pin down.
#
# Everything that would touch the machine (brew, open, defaults, curl, git,
# make, ya) is stubbed on PATH, HOME is a throwaway directory, and the scripts
# under test run on /bin/bash so bash 3.2 regressions cannot hide.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
common_sh="$repo_root/bootstrap/lib/common.sh"
system_bash="/bin/bash"

# --- the engine must be exercised on bash 3.2, not Homebrew's bash 5 ---------

if [[ ! -x "$system_bash" ]]; then
  printf 'Missing %s; the deploy engine must be tested on the macOS system bash.\n' "$system_bash" >&2
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

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/deploy-engine-smoke.XXXXXX")"
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

# Calls deploy_repo_path directly, so cases can use fixture content with spaces,
# non-ASCII and percent signs instead of whatever the repo happens to ship.
deploy_helper="$sandbox_root/deploy-once.sh"
cat >"$deploy_helper" <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail
source "$1"
deploy_repo_path "$2" "$3" "$4" "$5"
HELPER

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

assert_file_contains() {
  if grep -Fq "$2" "$1" 2>/dev/null; then
    pass
  else
    fail "$3" "$(cat "$1" 2>/dev/null || printf '(unreadable: %s)' "$1")"
  fi
}

assert_output_matches() {
  if printf '%s\n' "$1" | grep -Eqi "$2"; then
    pass
  else
    fail "$3" "$1"
  fi
}

# --- runner -----------------------------------------------------------------

RUN_ENV=()
last_output=""
last_status=0

run_home() {
  local home_dir="$1"
  shift

  last_status=0
  last_output="$(env \
    -u AI_ROUTER_HOME \
    -u BORDERS_START_SERVICE \
    -u DOTFILES_FORCE \
    -u XDG_CACHE_HOME \
    -u XDG_CONFIG_HOME \
    -u XDG_DATA_HOME \
    -u XDG_STATE_HOME \
    ${RUN_ENV[@]+"${RUN_ENV[@]}"} \
    "HOME=$home_dir" \
    "PATH=$stub_dir:$PATH" \
    "DOTFILES_STUB_LOG=$stub_log" \
    "$system_bash" "$@" 2>&1)" || last_status=$?
  RUN_ENV=()
}

new_home() {
  mktemp -d "$sandbox_root/home.XXXXXX"
}

backup_count() {
  find "$1" -name '*.backup_*' 2>/dev/null | wc -l | tr -d ' '
}

ledger_of() {
  printf '%s\n' "$1/.local/state/ai-first-dotfiles/backups.tsv"
}

# Snapshot of everything in a HOME except ~/.local, which holds the backup
# ledger uninstall.sh deliberately keeps as a record. Everything else has to
# come back exactly as it was.
home_snapshot() {
  local home_dir="$1"

  find "$home_dir" -mindepth 1 -not -path "$home_dir/.local" -not -path "$home_dir/.local/*" 2>/dev/null |
    LC_ALL=C sort |
    while IFS= read -r path; do
      if [[ -L "$path" ]]; then
        printf 'link %s -> %s\n' "${path#"$home_dir"}" "$(readlink "$path")"
      elif [[ -d "$path" ]]; then
        printf 'dir  %s\n' "${path#"$home_dir"}"
      else
        printf 'file %s %s\n' "${path#"$home_dir"}" "$(cksum <"$path")"
      fi
    done || true
}

# --- case: a user's own files survive redeploy ------------------------------
# The reason this batch exists. Everything else is secondary to this passing.

case_user_files_survive() {
  local home custom nested
  home="$(new_home)"
  custom="$home/.config/ai-router/prompts/my-own.md"
  nested="$home/.config/ai-router/prompts/personal/deep-note.md"

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  assert_equal 0 "$last_status" 'first ai-router deploy should succeed'
  assert_exists "$home/.config/ai-router/ai-router.sh" 'first deploy should write the router'

  mkdir -p "$(dirname "$nested")"
  printf 'mine\n' >"$custom"
  printf 'deeply mine\n' >"$nested"

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  assert_equal 0 "$last_status" 'redeploy should succeed'
  assert_exists "$custom" 'a user file in a deployed directory must survive redeploy'
  assert_exists "$nested" 'a user file in a new nested directory must survive redeploy'
  assert_equal 'mine' "$(cat "$custom" 2>/dev/null || true)" 'user file content must be untouched'

  # The whole target directory being moved aside is exactly the old bug.
  if [[ "$(find "$home/.config" -maxdepth 1 -name 'ai-router.backup_*' | wc -l | tr -d ' ')" -eq 0 ]]; then
    pass
  else
    fail 'the target directory must not be moved aside'
  fi
}

# --- case: redeploy is idempotent -------------------------------------------

case_redeploy_is_idempotent() {
  local home before after
  home="$(new_home)"

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  before="$(backup_count "$home")"

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  assert_equal 0 "$last_status" 'second deploy should succeed'
  assert_output_matches "$last_output" '^Unchanged: ' 'an unchanged directory should report itself as unchanged'

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  after="$(backup_count "$home")"
  assert_equal "$before" "$after" 'repeated deploys must not pile up backups'
  assert_equal 0 "$after" 'a clean first deploy has nothing to back up'
}

# --- case: a file changed on this machine is kept ---------------------------
# Not only hand edits: the AI router rewrites its own exports/ after every
# deploy. Overwriting a file the repo itself has not changed would undo that on
# every run and leave a fresh backup behind each time.

case_local_change_is_kept() {
  local home target
  home="$(new_home)"
  target="$home/.config/ai-router/config.json"

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  printf '{"mine": true}\n' >"$target"

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  assert_equal '{"mine": true}' "$(cat "$target" 2>/dev/null || true)" \
    'a local change must survive while the repo copy has not changed'
  assert_output_matches "$last_output" 'Kept local change' \
    'keeping a local change must be reported, not silent'
  assert_equal 0 "$(backup_count "$home")" 'keeping a local change must not create a backup'

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only
  assert_equal 0 "$(backup_count "$home")" 'repeated deploys over a local change must stay quiet'
}

# --- case: an upstream change wins, after a backup --------------------------

case_upstream_change_overwrites_after_backup() {
  local home fixture source_rel target ledger
  home="$(new_home)"
  fixture="$sandbox_root/upstream fixture"
  source_rel="home/thing"
  target="$home/.config/thing"
  ledger="$(ledger_of "$home")"

  mkdir -p "$fixture/$source_rel"
  printf 'v1\n' >"$fixture/$source_rel/settings.conf"

  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp1
  printf 'my own edit\n' >"$target/settings.conf"

  # Same content upstream: the local edit stays and nothing is backed up.
  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp2
  assert_equal 'my own edit' "$(cat "$target/settings.conf" 2>/dev/null || true)" \
    'an unchanged repo file must not overwrite a local edit'
  assert_equal 0 "$(backup_count "$home")" 'an unchanged repo file must not cause a backup'

  # Now the repo really does ship a new version: it wins, and the local edit is
  # backed up rather than dropped.
  printf 'v2\n' >"$fixture/$source_rel/settings.conf"
  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp3
  assert_equal 'v2' "$(cat "$target/settings.conf" 2>/dev/null || true)" \
    'a changed repo file must be deployed over a local edit'
  assert_equal 1 "$(backup_count "$home")" 'the overwritten local edit must be backed up exactly once'
  assert_equal 'my own edit' "$(cat "$target/settings.conf.backup_stamp3" 2>/dev/null || true)" \
    'the backup must hold the local edit'
  assert_file_contains "$ledger" 'settings.conf.backup_stamp3' 'the backup must be recorded in the ledger'

  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp4
  assert_equal 1 "$(backup_count "$home")" 'a settled deploy must not back up again'
}

# --- case: --force overwrites a local change --------------------------------

case_force_overwrites_local_change() {
  local home fixture source_rel target
  home="$(new_home)"
  fixture="$sandbox_root/force fixture"
  source_rel="home/thing"
  target="$home/.config/thing"

  mkdir -p "$fixture/$source_rel"
  printf 'repo version\n' >"$fixture/$source_rel/settings.conf"

  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp1
  printf 'my own edit\n' >"$target/settings.conf"

  RUN_ENV=(DOTFILES_FORCE=1)
  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp2
  assert_equal 'repo version' "$(cat "$target/settings.conf" 2>/dev/null || true)" \
    '--force must put the repo copy back'
  assert_equal 'my own edit' "$(cat "$target/settings.conf.backup_stamp2" 2>/dev/null || true)" \
    '--force must still back the local edit up first'
}

# --- case: symlinked file target is refused ---------------------------------

case_symlinked_file_is_refused() {
  local home
  home="$(new_home)"
  ln -sfn /tmp/somewhere-else "$home/.zshenv"

  run_home "$home" "$repo_root/bootstrap/install/zsh.sh" --deploy-only

  assert_output_matches "$last_output" 'symlink|symbolic' 'refusing a symlink must say so'
  assert_output_matches "$last_output" '\-\-force' 'the refusal must name the way to override it'
  if [[ "$last_status" -ne 0 ]]; then
    pass
  else
    fail 'a run that skipped a target must not exit 0' "$last_output"
  fi

  if [[ -L "$home/.zshenv" ]]; then
    pass
  else
    fail 'the symlink itself must be left alone'
  fi
  assert_equal '/tmp/somewhere-else' "$(readlink "$home/.zshenv")" 'the symlink must still point where it did'
  assert_equal 0 "$(backup_count "$home")" 'refusing must not move anything aside'

  # The other targets in the same script still have to be deployed: one path
  # managed by Stow must not block the other sixteen.
  assert_exists "$home/.config/zsh/.zshrc" 'a skipped target must not stop the remaining ones'

  # Refusing must not be recorded as a deploy. If the user later drops the
  # symlink and puts a plain file there, this is still a first deploy over
  # pre-existing config: the repo copy lands and their file is backed up.
  rm "$home/.zshenv"
  printf 'my own zshenv\n' >"$home/.zshenv"
  run_home "$home" "$repo_root/bootstrap/install/zsh.sh" --deploy-only
  assert_equal 0 "$last_status" 'the follow-up deploy should succeed'
  assert_equal 1 "$(backup_count "$home")" 'a refused target must not count as previously deployed'
  assert_file_contains "$home/.zshenv" 'ZDOTDIR' 'the repo copy must land once the symlink is gone'
}

# --- case: symlinked directory target is refused ----------------------------

case_symlinked_directory_is_refused() {
  local home elsewhere
  home="$(new_home)"
  elsewhere="$sandbox_root/other-manager"
  mkdir -p "$elsewhere" "$home/.config"
  printf 'not ours\n' >"$elsewhere/keep-me.txt"
  ln -sfn "$elsewhere" "$home/.config/ai-router"

  run_home "$home" "$repo_root/bootstrap/install/ai-router.sh" --deploy-only

  assert_output_matches "$last_output" 'symlink|symbolic' 'refusing a symlinked directory must say so'
  if [[ -L "$home/.config/ai-router" ]]; then
    pass
  else
    fail 'the symlinked directory must be left alone'
  fi
  assert_equal 'not ours' "$(cat "$elsewhere/keep-me.txt" 2>/dev/null || true)" \
    'nothing may be written through the link'
  assert_missing "$elsewhere/ai-router.sh" 'no repo file may be written through the link'
}

# --- case: a symlinked parent directory is not written through --------------

case_symlinked_parent_is_refused() {
  local home elsewhere
  home="$(new_home)"
  elsewhere="$sandbox_root/other-config"
  mkdir -p "$elsewhere"
  ln -sfn "$elsewhere" "$home/.config"

  run_home "$home" "$repo_root/bootstrap/install/zsh.sh" --deploy-only

  assert_output_matches "$last_output" 'symlink' 'refusing a symlinked parent must say so'
  assert_missing "$elsewhere/zsh" 'nothing may be created inside a symlinked parent'
  # $HOME itself is not below $HOME, so targets directly in it are unaffected;
  # a symlinked home directory or /var on macOS must not block a deploy.
  assert_exists "$home/.zshenv" 'targets outside the symlinked parent must still deploy'
}

# --- case: --force replaces a symlink, after backing it up ------------------

case_force_replaces_symlink() {
  local home backup
  home="$(new_home)"
  ln -sfn /tmp/somewhere-else "$home/.zshenv"

  run_home "$home" "$repo_root/bootstrap/install/zsh.sh" --deploy-only --force
  assert_equal 0 "$last_status" '--force should complete without skipping'

  if [[ -L "$home/.zshenv" ]]; then
    fail '--force should have replaced the symlink'
  else
    pass
  fi
  assert_exists "$home/.zshenv" '--force should deploy the real file'

  backup="$(find "$home" -maxdepth 1 -name '.zshenv.backup_*' | head -n 1)"
  if [[ -L "$backup" ]]; then
    pass
  else
    fail '--force must keep the original symlink as a backup, still a symlink' "$backup"
  fi
  assert_file_contains "$(ledger_of "$home")" "$backup" 'the forced backup must be in the ledger'
}

# --- case: DOTFILES_FORCE=1 works without a flag ----------------------------
# setup.sh does not forward --force, so the environment variable is the path a
# user actually has from `DOTFILES_FORCE=1 ./bootstrap/setup.sh deploy`.

case_force_env_var() {
  local home
  home="$(new_home)"
  ln -sfn /tmp/somewhere-else "$home/.ideavimrc"

  RUN_ENV=(DOTFILES_FORCE=1)
  run_home "$home" "$repo_root/bootstrap/install/ideavim.sh" --deploy-only
  assert_equal 0 "$last_status" 'DOTFILES_FORCE=1 should behave like --force'
  if [[ -L "$home/.ideavimrc" ]]; then
    fail 'DOTFILES_FORCE=1 should have replaced the symlink'
  else
    pass
  fi
}

# --- case: awkward paths, nesting, orphans and the ledger format ------------

case_fixture_paths_and_orphans() {
  local home fixture source_rel target ledger user_file line fields decoded
  home="$(new_home)"
  fixture="$sandbox_root/fixture repo"
  source_rel="home/my config"
  target="$home/.config/my config"
  ledger="$(ledger_of "$home")"

  mkdir -p "$fixture/$source_rel/nested dir/deeper"
  printf 'top\n' >"$fixture/$source_rel/top level.txt"
  printf 'deep\n' >"$fixture/$source_rel/nested dir/深层 file.txt"
  printf 'leaf\n' >"$fixture/$source_rel/nested dir/deeper/100% done.txt"
  printf 'doomed\n' >"$fixture/$source_rel/nested dir/dropped upstream.txt"
  # Glob characters in a filename must stay literal everywhere the engine
  # pattern-matches: the prune check, the manifest lookup, the ledger.
  printf 'globby\n' >"$fixture/$source_rel/nested dir/weird [1] *.txt"

  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp1
  assert_equal 0 "$last_status" 'fixture deploy should succeed'
  assert_exists "$target/top level.txt" 'a path with a space must deploy'
  assert_exists "$target/nested dir/深层 file.txt" 'a non-ASCII nested path must deploy'
  assert_exists "$target/nested dir/deeper/100% done.txt" 'a nested path with a percent sign must deploy'
  assert_exists "$target/nested dir/weird [1] *.txt" 'a path with glob characters must deploy'

  # Changed on this machine, unchanged in the repo: the local version stays, and
  # the fingerprint lookup has to find its entry despite the glob characters.
  printf 'edited\n' >"$target/nested dir/weird [1] *.txt"
  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp1b
  assert_equal 'edited' "$(cat "$target/nested dir/weird [1] *.txt" 2>/dev/null || true)" \
    'a local change to a glob-named file must be kept'
  assert_equal 0 "$(backup_count "$home")" 'a glob-named file must not churn backups'
  printf 'globby\n' >"$target/nested dir/weird [1] *.txt"

  # Ledger shape: four tab-separated fields on every record line.
  assert_exists "$ledger" 'a deploy must write the backup ledger'
  fields="$(awk -F'\t' '!/^#/ && NF != 4 { bad++ } END { printf "%d", bad + 0 }' "$ledger" 2>/dev/null || printf 'unreadable')"
  assert_equal 0 "$fields" 'every ledger record must have four tab-separated fields'

  line="$(awk -F'\t' '$2 == "home/my config/nested dir/深层 file.txt" { print $3 }' "$ledger" 2>/dev/null | head -n 1 || true)"
  decoded="$("$system_bash" -c 'source "$1"; ledger_decode "$2"' _ "$common_sh" "$line")"
  assert_equal "$target/nested dir/深层 file.txt" "$decoded" \
    'a ledger target with spaces and non-ASCII must round-trip'

  line="$(awk -F'\t' '$2 == "home/my config/nested dir/deeper/100%25 done.txt" { print $3 }' "$ledger" 2>/dev/null | head -n 1 || true)"
  decoded="$("$system_bash" -c 'source "$1"; ledger_decode "$2"' _ "$common_sh" "$line")"
  assert_equal "$target/nested dir/deeper/100% done.txt" "$decoded" \
    'a ledger path with a percent sign must round-trip'

  # A user file in a nested directory of the target, plus an upstream deletion.
  user_file="$target/nested dir/deeper/my notes.txt"
  printf 'mine\n' >"$user_file"
  rm "$fixture/$source_rel/nested dir/dropped upstream.txt"

  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp2
  assert_exists "$user_file" 'a nested user file must survive redeploy'
  assert_exists "$target/nested dir/dropped upstream.txt" \
    'a file dropped upstream must be kept, not deleted'
  assert_output_matches "$last_output" 'dropped upstream\.txt' \
    'a file dropped upstream must be reported so it is not invisible'
  assert_output_matches "$last_output" 'no longer shipped' \
    'the stale-file report must explain what it is showing'

  # Reporting it once is enough; the next deploy has nothing new to say.
  run_home "$home" "$deploy_helper" "$common_sh" "$fixture" "$source_rel" "$target" stamp3
  if printf '%s\n' "$last_output" | grep -Fq 'dropped upstream.txt'; then
    fail 'the stale-file report must not repeat on every deploy' "$last_output"
  else
    pass
  fi
  assert_equal 0 "$(backup_count "$home")" 'fixture redeploys must not create backups'
}

# --- case: uninstall dry run changes nothing --------------------------------

case_uninstall_dry_run_is_inert() {
  local home before after
  home="$(new_home)"

  run_home "$home" "$repo_root/bootstrap/install/zsh.sh" --deploy-only
  before="$(home_snapshot "$home")"

  run_home "$home" "$repo_root/bootstrap/uninstall.sh" --files-only
  assert_equal 0 "$last_status" 'a dry run should succeed'
  assert_output_matches "$last_output" 'dry run' 'a dry run must say it is a dry run'
  assert_output_matches "$last_output" '\-\-apply' 'a dry run must name the flag that performs it'

  after="$(home_snapshot "$home")"
  assert_equal "$before" "$after" 'a dry run must not change anything'
}

# --- case: uninstall --apply restores the pre-deploy state ------------------

case_uninstall_apply_restores() {
  local home before after
  home="$(new_home)"
  mkdir -p "$home/.config/zsh"
  printf 'my own zshrc\n' >"$home/.config/zsh/.zshrc"
  printf 'my own notes\n' >"$home/.config/zsh/my-notes.txt"

  before="$(home_snapshot "$home")"

  run_home "$home" "$repo_root/bootstrap/install/zsh.sh" --deploy-only
  assert_equal 0 "$last_status" 'deploy before uninstall should succeed'
  assert_exists "$home/.zshenv" 'deploy should have written a file to remove again'

  run_home "$home" "$repo_root/bootstrap/uninstall.sh" --files-only --apply
  assert_equal 0 "$last_status" 'uninstall --apply should succeed'

  after="$(home_snapshot "$home")"
  assert_equal "$before" "$after" 'uninstall --apply must restore the pre-deploy HOME'
  assert_equal 'my own zshrc' "$(cat "$home/.config/zsh/.zshrc" 2>/dev/null || true)" \
    'the user version of an overwritten file must come back'
  assert_equal 0 "$(backup_count "$home")" 'a completed rollback must leave no backups behind'
}

# --- case: uninstall keeps what the user changed after deploying ------------

case_uninstall_keeps_local_edits() {
  local home
  home="$(new_home)"

  run_home "$home" "$repo_root/bootstrap/install/zsh.sh" --deploy-only
  printf '# my tweak\n' >>"$home/.config/zsh/aliases.zsh"

  run_home "$home" "$repo_root/bootstrap/uninstall.sh" --files-only --apply
  assert_exists "$home/.config/zsh/aliases.zsh" 'a file edited after deploy must not be deleted'
  assert_file_contains "$home/.config/zsh/aliases.zsh" '# my tweak' 'the local edit must be intact'
  assert_missing "$home/.zshenv" 'untouched deployed files must still be removed'
}

# --- case: uninstall lists the system side effects it would undo ------------

case_uninstall_lists_system_side_effects() {
  local home
  home="$(new_home)"

  run_home "$home" "$repo_root/bootstrap/uninstall.sh" --system-only
  assert_equal 0 "$last_status" 'the system-only dry run should succeed'
  assert_output_matches "$last_output" 'NSWindowShouldDragOnGesture' \
    'uninstall must cover the AeroSpace default'
  assert_output_matches "$last_output" 'unsetenv PATH' \
    'uninstall must cover the GUI PATH launchctl setting'
  assert_output_matches "$last_output" 'brew services stop (sketchybar|borders)' \
    'uninstall must cover the services the installers start'
}

# --- case: an unwritable state directory must not stop a deploy -------------

case_state_dir_failure_is_survivable() {
  local home
  home="$(new_home)"
  # A plain file where the state directory belongs: mkdir -p cannot win.
  mkdir -p "$home/.local"
  printf 'in the way\n' >"$home/.local/state"

  run_home "$home" "$repo_root/bootstrap/install/ideavim.sh" --deploy-only
  assert_equal 0 "$last_status" 'a ledger that cannot be written must not fail the deploy'
  assert_exists "$home/.ideavimrc" 'the deploy must still happen'
  assert_output_matches "$last_output" 'cannot write' 'the user must be told the ledger was skipped'
}

# A skipped symlink must not stop the modules that come after it. The people who
# symlink their dotfiles are exactly the ones this protection is for, so letting
# exit 3 abort setup.sh would hand them a half-deployed HOME.
case_skipped_symlink_does_not_abort_setup() {
  local home
  home="$(new_home)"

  ln -sfn /tmp/managed-elsewhere "$home/.zshenv"

  RUN_ENV=("DOTFILES_SKIP_PREFLIGHT=1")
  run_home "$home" "$repo_root/bootstrap/setup.sh" deploy

  assert_equal 0 "$last_status" 'a skipped symlink must not fail the whole run'
  assert_exists "$home/.config/ai-router" 'modules after the skip must still deploy'
  assert_exists "$home/.hammerspoon" 'modules after the skip must still deploy'
  assert_output_matches "$last_output" 'left some paths untouched' \
    'the run must report what it skipped'

  if [[ ! -L "$home/.zshenv" ]]; then
    fail 'the symlink must survive the full setup run'
  fi
}

# --- run --------------------------------------------------------------------

case_user_files_survive
case_redeploy_is_idempotent
case_local_change_is_kept
case_upstream_change_overwrites_after_backup
case_force_overwrites_local_change
case_symlinked_file_is_refused
case_symlinked_directory_is_refused
case_symlinked_parent_is_refused
case_force_replaces_symlink
case_force_env_var
case_fixture_paths_and_orphans
case_uninstall_dry_run_is_inert
case_uninstall_apply_restores
case_uninstall_keeps_local_edits
case_uninstall_lists_system_side_effects
case_state_dir_failure_is_survivable
case_skipped_symlink_does_not_abort_setup

if [[ "$failures" -gt 0 ]]; then
  printf '\ndeploy_engine_smoke.sh: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi

printf 'deploy_engine_smoke.sh: ok (%s checks on bash %s)\n' "$checks" "$system_bash_version"
