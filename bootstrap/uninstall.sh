#!/usr/bin/env bash
set -euo pipefail

# Undoes what bootstrap/setup.sh did, using the backup ledger every deploy
# writes (see deploy_repo_path in bootstrap/lib/common.sh).
#
# This is the one script here whose whole job is to move things around inside
# $HOME, so it prints a plan and changes nothing unless --apply is passed.
#
# Two rules it keeps:
#   - Nothing is deleted unless it is byte-identical to the copy this repo
#     ships, which proves it is our deployed file and reproducible from git.
#     Anything else is moved aside, never removed.
#   - Symlinks and directories are never deleted. Directories are removed with
#     rmdir, which refuses to touch a directory that still holds anything.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
repo_root="$(repo_root_dir)"

apply=0
do_files=1
do_system=1
ledger_file="$(dotfiles_ledger_path)"
stamp="$(date +%Y%m%d_%H%M%S)"

restored=0
removed=0
kept=0
skipped=0
system_actions=0

usage() {
  cat <<'EOF'
Usage: ./bootstrap/uninstall.sh [options]

Rolls back config deployed by ./bootstrap/setup.sh, newest change first, and
undoes the system-level side effects the install scripts caused.

Prints the plan and changes nothing unless --apply is given.

Options:
  --apply         Actually perform the plan. Without it this is a dry run.
  --files-only    Only restore deployed files; leave system settings alone.
  --system-only   Only undo system settings; leave deployed files alone.
  --ledger PATH   Read a different backup ledger.
  -h, --help      Show this help.

Ledger:
  ${XDG_STATE_HOME:-$HOME/.local/state}/ai-first-dotfiles/backups.tsv
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=1
      ;;
    --files-only)
      do_system=0
      ;;
    --system-only)
      do_files=0
      ;;
    --ledger)
      if [[ "$#" -lt 2 ]]; then
        printf -- '--ledger needs a path\n\n' >&2
        usage >&2
        exit 1
      fi
      ledger_file="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

seen_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-uninstall.XXXXXX")"
trap 'rm -f "$seen_file"' EXIT

report() {
  local action="$1"
  local detail="$2"

  printf '%-8s %s\n' "$action" "$detail"
}

# True when the file at $2 is byte-identical to the copy this repo ships at $1,
# i.e. it is our deployed file and nothing of the user's is in it.
is_repo_copy() {
  local source_rel="$1"
  local target="$2"

  [[ -n "$source_rel" && "$source_rel" != "-" ]] || return 1
  [[ -f "$repo_root/$source_rel" ]] || return 1
  [[ -f "$target" && ! -L "$target" ]] || return 1

  cmp -s "$repo_root/$source_rel" "$target"
}

move_aside() {
  local target="$1"
  local aside="${target}.local_${stamp}"
  local suffix=1

  while [[ -e "$aside" || -L "$aside" ]]; do
    aside="${target}.local_${stamp}_${suffix}"
    suffix=$((suffix + 1))
  done

  report 'aside' "$target -> $aside"
  if [[ "$apply" -eq 1 ]]; then
    mv "$target" "$aside"
  fi
}

# Entries are replayed newest first and each target is acted on once, so the
# most recent change is the one undone. Going further back for the same path
# would start undoing edits the user made between two deploys.
already_seen() {
  local key="$1"

  if grep -Fxq "$key" "$seen_file" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$key" >>"$seen_file"
  return 1
}

restore_created_entry() {
  local source_rel="$1"
  local target="$2"

  if [[ -L "$target" ]]; then
    report 'keep' "$target (now a symlink, not ours to remove)"
    kept=$((kept + 1))
    return 0
  fi

  if [[ -d "$target" ]]; then
    report 'rmdir' "$target (only if empty once the steps above are done)"
    if [[ "$apply" -eq 1 ]]; then
      rmdir "$target" 2>/dev/null || true
    fi
    removed=$((removed + 1))
    return 0
  fi

  if [[ ! -e "$target" ]]; then
    report 'skip' "$target (already gone)"
    skipped=$((skipped + 1))
    return 0
  fi

  if is_repo_copy "$source_rel" "$target"; then
    report 'remove' "$target (added by this repo, unmodified)"
    if [[ "$apply" -eq 1 ]]; then
      rm -f "$target"
    fi
    removed=$((removed + 1))
    return 0
  fi

  report 'keep' "$target (changed since it was deployed)"
  kept=$((kept + 1))
}

restore_backup_entry() {
  local source_rel="$1"
  local target="$2"
  local backup="$3"

  if [[ ! -e "$backup" && ! -L "$backup" ]]; then
    report 'skip' "$target (backup is gone: $backup)"
    skipped=$((skipped + 1))
    return 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    if is_repo_copy "$source_rel" "$target"; then
      report 'remove' "$target (deployed copy, unmodified)"
      if [[ "$apply" -eq 1 ]]; then
        rm -f "$target"
      fi
    else
      move_aside "$target"
    fi
  fi

  report 'restore' "$target <- $backup"
  if [[ "$apply" -eq 1 ]]; then
    mv "$backup" "$target"
  fi
  restored=$((restored + 1))
}

restore_files() {
  local timestamp source_rel target backup line_count=0

  if [[ ! -f "$ledger_file" ]]; then
    printf 'No backup ledger at %s, so nothing was deployed from this repo (or the state directory was cleared).\n' \
      "$ledger_file"
    return 0
  fi

  printf 'Ledger: %s\n\n' "$ledger_file"

  while IFS=$'\t' read -r timestamp source_rel target backup; do
    case "$timestamp" in
      '#'*|'')
        continue
        ;;
    esac
    [[ -n "${target:-}" ]] || continue

    source_rel="$(ledger_decode "$source_rel")"
    target="$(ledger_decode "$target")"
    backup="$(ledger_decode "${backup:--}")"

    already_seen "$(ledger_encode "$target")" && continue
    line_count=$((line_count + 1))

    if [[ "$backup" == "-" ]]; then
      restore_created_entry "$source_rel" "$target"
    else
      restore_backup_entry "$source_rel" "$target" "$backup"
    fi
  done < <(awk '{ lines[NR] = $0 } END { for (i = NR; i >= 1; i--) print lines[i] }' "$ledger_file")

  if [[ "$line_count" -eq 0 ]]; then
    printf 'The ledger has no entries; nothing to roll back.\n'
    return 0
  fi

  local manifest_dir
  manifest_dir="$(dotfiles_state_dir)/manifests"
  if [[ -d "$manifest_dir" ]]; then
    report 'clean' "$manifest_dir (deploy bookkeeping)"
    if [[ "$apply" -eq 1 ]]; then
      rm -rf "$manifest_dir"
    fi
  fi

  printf '\n%s restored, %s removed, %s kept, %s skipped.\n' \
    "$restored" "$removed" "$kept" "$skipped"
  printf 'The ledger itself is left in place as a record.\n'
}

run_system_command() {
  local description="$1"
  shift

  report 'system' "$description"
  system_actions=$((system_actions + 1))
  if [[ "$apply" -eq 1 ]]; then
    "$@" >/dev/null 2>&1 || true
  fi
}

undo_aerospace_default() {
  if ! command -v defaults >/dev/null 2>&1; then
    return 0
  fi
  if ! defaults read -g NSWindowShouldDragOnGesture >/dev/null 2>&1; then
    report 'skip' 'NSWindowShouldDragOnGesture is not set'
    return 0
  fi

  # bootstrap/install/aerospace.sh sets this to true. There is no record of what
  # it was before, so the key is deleted and macOS falls back to its default.
  run_system_command 'defaults delete -g NSWindowShouldDragOnGesture' \
    defaults delete -g NSWindowShouldDragOnGesture
}

undo_gui_path() {
  local uid label plist

  if [[ ! -x /bin/launchctl ]]; then
    return 0
  fi

  uid="$(id -u)"
  label="com.aklman.gui-path"
  plist="$HOME/Library/LaunchAgents/$label.plist"

  if [[ -f "$plist" ]]; then
    run_system_command "/bin/launchctl bootout gui/$uid $plist" \
      /bin/launchctl bootout "gui/$uid" "$plist"
  fi

  # bootstrap/install/gui-path.sh sets the GUI session PATH. unsetenv puts it
  # back to what launchd hands out by default; log out to be sure it took.
  run_system_command '/bin/launchctl unsetenv PATH' \
    /bin/launchctl unsetenv PATH
}

undo_brew_services() {
  local service

  if ! command -v brew >/dev/null 2>&1; then
    return 0
  fi

  for service in sketchybar borders; do
    run_system_command "brew services stop $service" \
      brew services stop "$service"
  done
}

undo_system_side_effects() {
  printf '\nSystem side effects:\n\n'

  undo_aerospace_default
  undo_gui_path
  undo_brew_services

  if [[ "$system_actions" -eq 0 ]]; then
    printf 'Nothing to undo.\n'
    return 0
  fi

  printf '\nHomebrew packages, casks and App Store apps are not touched. Remove the ones\n'
  printf 'you no longer want with `brew uninstall`, and restart GUI apps so they pick up\n'
  printf 'the original PATH.\n'
}

if [[ "$apply" -eq 1 ]]; then
  printf 'Applying. This moves files inside %s.\n\n' "$HOME"
else
  printf 'Dry run: nothing is changed. Re-run with --apply to perform this plan.\n\n'
fi

if [[ "$do_files" -eq 1 ]]; then
  restore_files
fi

if [[ "$do_system" -eq 1 ]]; then
  undo_system_side_effects
fi

if [[ "$apply" -eq 0 ]]; then
  printf '\nNothing was changed. Re-run with --apply to perform this plan.\n'
fi
