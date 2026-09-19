#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/smoke/lib/assert.sh"
root="$(mktemp -d "${TMPDIR:-/tmp}/safety-boundary.XXXXXX")"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/bin" "$root/source" "$root/home"
common="$repo_root/bootstrap/lib/common.sh"
cat >"$root/bin/mv" <<'STUB'
#!/bin/bash
if [ "${FAIL_BACKUP:-}" = "${1:-}" ] || [ "${FAIL_DEST:-}" = "${2:-}" ]; then exit 73; fi
exec /bin/mv "$@"
STUB
cat >"$root/bin/cp" <<'STUB'
#!/bin/bash
if [ "${FAIL_COPY:-}" = "${1:-}" ]; then exit 73; fi
if [ -n "${EDIT_DURING_COPY:-}" ] && [ "${1:-}" = "$RACE_SOURCE" ]; then
  printf 'concurrent-edit\n' >"$EDIT_DURING_COPY"
fi
exec /bin/cp "$@"
STUB
cat >"$root/bin/ipc" <<'STUB'
#!/bin/bash
printf '%s %s\n' "${0##*/}" "$*" >>"$IPC_LOG"
exit 97
STUB
for name in aerospace hs sketchybar brew open defaults launchctl; do cp "$root/bin/ipc" "$root/bin/$name"; done
chmod +x "$root/bin/"*
run() {
  status=0
  output="$(env -i HOME="$home" XDG_STATE_HOME="$home/.state" TMPDIR="$root" \
    PATH="$root/bin:/usr/bin:/bin:/usr/sbin:/sbin" IPC_LOG="$root/ipc.log" \
    FAIL_BACKUP="${FAIL_BACKUP:-}" FAIL_COPY="${FAIL_COPY:-}" FAIL_DEST="${FAIL_DEST:-}" \
    EDIT_DURING_COPY="${EDIT_DURING_COPY:-}" RACE_SOURCE="$root/source/item" \
    DOTFILES_SKIP_PREFLIGHT=1 "$@" 2>&1)" || status=$?
}
deploy() { run /bin/bash -c 'source "$1"; deploy_repo_path "$2" item "$HOME/item" test' _ "$common" "$root/source"; }
new_home() { home="$(mktemp -d "$root/home.XXXXXX")"; }

# Failed backup must retain the successful v1 baseline, not record planned v2.
new_home
printf 'v1\n' >"$root/source/item"
deploy
assert_equal 0 "$status" 'initial deploy succeeds'
printf 'v2\n' >"$root/source/item"
FAIL_BACKUP="$home/item"; deploy; unset FAIL_BACKUP
assert_equal 3 "$status" 'backup failure is nonzero'
assert_equal v1 "$(cat "$home/item")" 'backup failure preserves original'
deploy
assert_equal 0 "$status" 'backup retry succeeds without force'
assert_equal v2 "$(cat "$home/item")" 'backup retry deploys new source'

# Stage-copy failure has the same retry contract, no partial live target.
printf 'v3\n' >"$root/source/item"
FAIL_COPY="$root/source/item"; deploy; unset FAIL_COPY
assert_equal 3 "$status" 'copy failure is nonzero'
assert_equal v2 "$(cat "$home/item")" 'copy failure leaves old file in place'
deploy
assert_equal v3 "$(cat "$home/item")" 'copy retry reaches v3'

printf 'user-edit\n' >"$home/item"
printf 'v4\n' >"$root/source/item"
deploy
assert_equal 3 "$status" 'both changed is a conflict'
assert_contains "$output" 'both local and upstream changed' 'conflict is explained'
assert_equal user-edit "$(cat "$home/item")" 'conflict preserves user content'
deploy
assert_equal 3 "$status" 'retry does not erase conflict baseline'

# Missing/unwritable recovery state refuses the write before backing up.
new_home
printf 'v1\n' >"$root/source/item"
deploy
run /bin/bash -c 'source "$1"; deploy_manifest_path "$HOME/item"' _ "$common"
manifest="$output"
printf 'v2\n' >"$root/source/item"
FAIL_DEST="$manifest"; deploy; unset FAIL_DEST
assert_equal 1 "$status" 'manifest commit failure is nonzero'
deploy
assert_equal 0 "$status" 'manifest failure can be retried without force'
assert_equal v2 "$(cat "$home/item")" 'manifest retry confirms the actual installed content'

printf 'v3\n' >"$root/source/item"
chmod 000 "$manifest"
deploy
chmod 600 "$manifest"
assert_equal 1 "$status" 'unreadable baseline is not treated as a first install'
assert_equal v2 "$(cat "$home/item")" 'unreadable baseline refuses replacement'

EDIT_DURING_COPY="$home/item"; deploy; unset EDIT_DURING_COPY
assert_equal 3 "$status" 'concurrent edit during staging is a conflict'
assert_equal concurrent-edit "$(cat "$home/item")" 'staging never erases the concurrent edit'

# A final rename failure retains an adjacent backup and is retryable.
new_home
printf 'v1\n' >"$root/source/item"
deploy
printf 'v2\n' >"$root/source/item"
FAIL_DEST="$home/item"; deploy; unset FAIL_DEST
assert_equal 3 "$status" 'final replacement failure is nonzero'
assert_equal v1 "$(cat "$home/item.backup_test")" 'failed final rename retains previous content in backup'
deploy
assert_equal 0 "$status" 'final rename failure can be retried without force'
assert_equal v2 "$(cat "$home/item")" 'final rename retry reaches intended source'

new_home
mkdir -p "$home/.state/ai-first-dotfiles/backups.tsv"
printf 'before\n' >"$home/item"
deploy
assert_equal 1 "$status" 'unwritable ledger refuses deployment'
assert_equal before "$(cat "$home/item")" 'ledger failure leaves original'
new_home
mkdir -p "$home/.state/ai-first-dotfiles/pending"
chmod 500 "$home/.state/ai-first-dotfiles/pending"
printf 'before\n' >"$home/item"
deploy
chmod 700 "$home/.state/ai-first-dotfiles/pending"
assert_equal 3 "$status" 'unwritable write-ahead record refuses replacement'
assert_equal before "$(cat "$home/item")" 'journal failure leaves original'

# Force only replaces the leaf link; it never follows a linked ancestor.
new_home
mkdir -p "$root/outside/app"
printf 'outside\n' >"$root/outside/app/item"
ln -s "$root/outside" "$home/.config"
for force in 0 1; do
  run /bin/bash -c 'source "$1"; DOTFILES_FORCE="$3"; deploy_repo_path "$2" item "$HOME/.config/app/item" test' _ "$common" "$root/source" "$force"
  assert_equal 3 "$status" 'existing subdirectory below symlink is refused'
  assert_equal outside "$(cat "$root/outside/app/item")" 'ancestor target stays unchanged even with force'
done

# Cooperative single writer: stale or active locks require explicit inspection.
new_home
mkdir -p "$home/.state/ai-first-dotfiles/write.lock"
deploy
assert_equal 1 "$status" 'a second writer cannot acquire the HOME lock'
assert_path_absent "$home/item" 'a blocked writer does not deploy'

# Workspace installer must not render after refusing its TOML target.
new_home
mkdir -p "$home/.config/ai-first"
cp "$repo_root/bootstrap/presets/minimal.conf" "$home/.config/ai-first/profile.conf"
cp "$repo_root/home/.aerospace.toml" "$root/other.toml"
before="$(cksum <"$root/other.toml")"
ln -s "$root/other.toml" "$home/.aerospace.toml"
run /bin/bash "$repo_root/bootstrap/install/aerospace.sh" --deploy-only
assert_equal 3 "$status" 'linked TOML installer reports incomplete deployment'
assert_equal "$before" "$(cksum <"$root/other.toml")" 'refused TOML is not modified by renderer'
assert_path_absent "$root/ipc.log" 'deploy-only issues no IPC, even on refusal'
run /bin/bash "$repo_root/home/.config/aerospace/render-app-rules.sh" "$home/.aerospace.toml"
assert_equal 1 "$status" 'standalone renderer refuses a linked destination too'
assert_equal "$before" "$(cksum <"$root/other.toml")" 'standalone refusal leaves linked content unchanged'

new_home
mkdir -p "$home/.config/ai-first"
cp "$repo_root/bootstrap/presets/minimal.conf" "$home/.config/ai-first/profile.conf"
run /bin/bash "$repo_root/bootstrap/install/aerospace.sh" --deploy-only
assert_equal 0 "$status" 'normal workspace deploy succeeds without IPC'
assert_path_absent "$root/ipc.log" 'successful deploy-only also issues no IPC'
printf 'id|org.example.Editor|2|prefer|tiling\n' >>"$home/.config/aerospace/app-routes.conf"
run /bin/bash "$home/.config/aerospace/render-app-rules.sh"
assert_equal 0 "$status" 'standalone app rendering succeeds'
assert_path_absent "$root/ipc.log" 'standalone renderer does not reload services'

# A late app renderer error must leave the complete old TOML intact.
before="$(cksum <"$home/.aerospace.toml")"
printf '#!/bin/bash\nexit 65\n' >"$home/.config/aerospace/app-defaults.sh"
chmod +x "$home/.config/aerospace/app-defaults.sh"
run /bin/bash "$home/.config/aerospace/render-layout.sh"
assert_equal 1 "$status" 'app renderer failure propagates'
assert_equal "$before" "$(cksum <"$home/.aerospace.toml")" 'late rendering failure does not partially write layout'

# Export/semicolon syntax never turns the data channel back into execution.
printf 'export AEROSPACE_MAIN_MONITOR_NAME="$(touch %s)Display"\n' "$root/executed" >"$home/.config/aerospace/displays.conf"
run /bin/bash "$home/.config/aerospace/recording-target.sh"
assert_equal 65 "$status" 'invalid shell data fails with configuration error'
assert_path_absent "$root/executed" 'invalid shell data never executes'
assert_contains "$output" 'displays.conf:1:' 'parse error gives file and line'

smoke_summary safety_boundary_smoke.sh
