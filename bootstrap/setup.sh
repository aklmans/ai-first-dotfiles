#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
repo_root="$(repo_root_dir)"

dry_run=0
no_brew=0
deploy_only=0
install_only=0

usage() {
  cat <<'EOF'
Usage: ./bootstrap/setup.sh [profile...] [options]

Profiles:
  all           Recommended bootstrap: packages, GUI PATH, Sublime, desktop, ai, media
  packages      Homebrew packages required by the recommended setup
  packages-all  Every Homebrew profile in bootstrap/brew.sh
  gui-path      Make Homebrew tools visible to GUI-launched apps
  shell         zsh, Starship, Kaku, Yazi, IdeaVim
  sublime       Sublime Text Terminal package integration
  desktop       Karabiner, AeroSpace, SketchyBar, Borders, Hammerspoon
  extras        BetterTouchTool, Warp
  ai            AI Workflow Router
  media         mpv
  app-store     App Store apps from manifests/app-store
  deploy        Deploy all tracked config without package installation

Deliberately not part of "all":
  shell     Installing it points ~/.zshenv at this repo, which is the most
            invasive thing in here and the hardest to undo by hand. Everything
            else works without it. Ask for it: ./bootstrap/setup.sh shell
  extras    BetterTouchTool is free for 45 days and paid after that; Warp is
            closed source and asks you to sign in. Nothing else here depends on
            either: ./bootstrap/setup.sh extras
  app-store Nothing here needs an App Store app, and the manifests ship empty.
            Fill in manifests/app-store/mas-default.txt first, then ask for it:
            ./bootstrap/setup.sh app-store

Options:
  --no-brew       Skip Homebrew commands where possible.
  --deploy-only   Deploy config only. Installs nothing, starts nothing, and
                  changes no macOS settings.
  --install-only  Install packages/external dependencies only.
  --dry-run       Print what would run, including the paths under $HOME that
                  would be written. Nothing is executed.
  -h, --help      Show this help.

Requires an Apple Silicon Mac. The desktop layer hard-codes the /opt/homebrew
prefix, so an Intel install would finish without an error and leave nothing
wired up; this refuses before it writes anything instead. --dry-run still
previews on any machine.

Environment:
  DOTFILES_SKIP_PREFLIGHT=1  Skip the Apple Silicon, brew, git and Xcode CLT
                             prerequisite checks.
  DOTFILES_FORCE=1           Replace symlinked targets and local changes,
                             backing up whatever is replaced.

Exit status:
  0  every step ran, or some paths were left untouched (reported at the end)
  1  at least one step failed. The rest of the run still happened and the
     failures are listed at the end.
EOF
}

# ---------------------------------------------------------------------------
# Step results
#
# A profile is a list of independent steps, and this script used to stop at the
# first one that returned non-zero. A single brew hiccup inside sketchybar
# therefore ended the whole run: borders, BetterTouchTool, Hammerspoon, the AI
# router and mpv were never reached, and all the user saw was one error from the
# middle of the list with no idea what had and had not been installed.
#
# So every step's exit code is captured here and the run always continues to the
# end. Two kinds of non-zero are kept apart, because they mean opposite things:
#
#   3      The deploy engine refused to touch paths another tool manages
#          (see deploy_report_skips in lib/common.sh). Nothing was overwritten
#          and nothing is broken, so the run still exits 0.
#   other  A real failure. It is collected, named at the end, and makes the run
#          exit non-zero so nothing automated mistakes a partial install for a
#          complete one.
# ---------------------------------------------------------------------------
skipped_modules=0
failed_steps=()

step_label() {
  local label="${1#"$repo_root/"}"
  local arg
  shift || true

  printf '%s' "$label"
  for arg in "$@"; do
    printf ' %s' "$arg"
  done
}

run_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'

  if [[ "$dry_run" -eq 1 ]]; then
    # --install-only writes nothing under $HOME, so listing deploy targets there
    # would promise something the real run does not do.
    if [[ "$install_only" -eq 0 ]]; then
      preview_deploy_targets "$1"
    fi
    return 0
  fi

  local status=0
  "$@" || status=$?

  case "$status" in
    0)
      return 0
      ;;
    3)
      skipped_modules=$((skipped_modules + 1))
      return 0
      ;;
    130|131|143)
      # Killed by SIGINT, SIGQUIT or SIGTERM. That is somebody stopping this
      # run, not a step that failed, and carrying on would install another dozen
      # things after they asked for none. `cmd || status=$?` swallows the signal
      # that used to end the script, so it has to be honoured explicitly.
      printf '\nStopped: %s was interrupted (exit %s).\n' "$(step_label "$@")" "$status" >&2
      report_skipped_modules
      report_failed_steps || true
      exit "$status"
      ;;
  esac

  failed_steps+=("$(step_label "$@") (exit $status)")
  printf '\nStep failed (exit %s): %s\n' "$status" "$(step_label "$@")" >&2
  printf 'Continuing with the rest of this run; the failures are listed at the end.\n\n' >&2
  return 0
}

# Plain-string assignments seen so far in the module being previewed, framed in
# newlines so a lookup can anchor on whole lines without forking. Same shape as
# the deploy manifest in lib/common.sh.
preview_vars=""

preview_lookup_var() {
  local name="$1"
  local rest

  [[ -n "$preview_vars" ]] || return 1

  rest="${preview_vars#*$'\n'"$name"$'\t'}"
  [[ "$rest" != "$preview_vars" ]] || return 1

  printf '%s' "${rest%%$'\n'*}"
}

# Modules spell their targets either inline ("$HOME/.config/borders") or through
# a variable set at the top of the script ("$plist", "$target_path"). Resolve a
# leading reference of either form so the preview shows a real path instead of
# the name of a shell variable the reader cannot see.
preview_expand_path() {
  local value="$1"
  local guard=0
  local name rest resolved

  while [[ "$value" == \$* && "$guard" -lt 5 ]]; do
    guard=$((guard + 1))
    name="${value#\$}"
    rest=""

    case "$name" in
      \{*\}*)
        rest="${name#*\}}"
        name="${name#\{}"
        name="${name%%\}*}"
        ;;
      */*)
        rest="/${name#*/}"
        name="${name%%/*}"
        ;;
    esac

    if [[ "$name" == "HOME" ]]; then
      resolved="$HOME"
    else
      resolved="$(preview_lookup_var "$name")" || break
    fi

    value="$resolved$rest"
  done

  printf '%s' "$value"
}

# --dry-run used to print sixteen module invocations and nothing else, which is
# almost no information. The one thing a stranger needs before running this is
# which paths under their own $HOME it would write to, and the module scripts
# are the source of truth for that, so their deploy_repo_path calls are read out
# of them here. Read, not run: a preview must never execute a module.
preview_deploy_targets() {
  local script="$1"
  local line logical source_rel source_path target files count
  local pattern='deploy_repo_path[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)"'
  local assignment='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)="([^"`]*)"[[:space:]]*$'

  [[ -f "$script" ]] || return 0

  preview_vars=$'\n'
  logical=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Long deploy calls are wrapped across several lines; rejoin them first.
    if [[ "$line" == *\\ ]]; then
      logical="$logical${line%\\} "
      continue
    fi
    logical="$logical$line"

    # Remember plain assignments so a target named through one can be resolved.
    # Anything with a command substitution in it is a value only running the
    # module could know, and a preview does not run anything.
    if [[ "$logical" =~ $assignment ]]; then
      case "${BASH_REMATCH[2]}" in
        *'$('*)
          ;;
        *)
          preview_vars="${preview_vars}${BASH_REMATCH[1]}"$'\t'"${BASH_REMATCH[2]}"$'\n'
          ;;
      esac
    fi

    if [[ "$logical" =~ $pattern ]]; then
      source_rel="${BASH_REMATCH[2]}"
      target="$(preview_expand_path "${BASH_REMATCH[3]}")"
      source_path="$repo_root/$source_rel"

      count=1
      if [[ -d "$source_path" ]]; then
        count="$(find "$source_path" -type f 2>/dev/null | wc -l | tr -d ' ')"
      fi
      if [[ "$count" == "1" ]]; then
        files='1 file'
      else
        files="$count files"
      fi

      if [[ -L "$target" ]]; then
        printf '    %s (symlink; would be left untouched)\n' "$target"
      elif [[ -e "$target" ]]; then
        printf '    %s (exists; %s from %s, whatever is replaced is backed up first)\n' \
          "$target" "$files" "$source_rel"
      else
        printf '    %s (new; %s from %s)\n' "$target" "$files" "$source_rel"
      fi
    fi

    logical=""
  done <"$script"
}

report_skipped_modules() {
  [[ "$skipped_modules" -gt 0 ]] || return 0
  printf '\n%s module(s) left some paths untouched; see the notes above.\n' "$skipped_modules" >&2
  printf 'Nothing there was overwritten and nothing there failed. Re-run with\n' >&2
  printf 'DOTFILES_FORCE=1 to replace them.\n' >&2
}

report_failed_steps() {
  local entry

  [[ "${#failed_steps[@]}" -gt 0 ]] || return 0

  printf '\n%s step(s) failed:\n\n' "${#failed_steps[@]}" >&2
  for entry in ${failed_steps[@]+"${failed_steps[@]}"}; do
    printf '  - %s\n' "$entry" >&2
  done
  printf '\nEverything else was still attempted, so this is a partial install rather\n' >&2
  printf 'than a broken one. Fix the causes above and re-run the same profile:\n' >&2
  printf 'every step here is safe to run again.\n' >&2
  return 1
}

module_flags() {
  if [[ "$deploy_only" -eq 1 ]]; then
    printf '%s\n' --deploy-only
    return 0
  fi

  if [[ "$install_only" -eq 1 ]]; then
    printf '%s\n' --install-only
  fi

  if [[ "$no_brew" -eq 1 ]]; then
    printf '%s\n' --no-brew
  fi
}

run_module() {
  local module="$1"
  shift || true

  local -a flags
  flags=()
  while IFS= read -r flag; do
    [[ -n "$flag" ]] && flags+=("$flag")
  done < <(module_flags)

  if [[ "${#flags[@]}" -gt 0 ]]; then
    run_cmd "$repo_root/bootstrap/install/$module.sh" "${flags[@]}" "$@"
  else
    run_cmd "$repo_root/bootstrap/install/$module.sh" "$@"
  fi
}

run_brew_profile() {
  local profiles=("$@")

  if [[ "$no_brew" -eq 1 || "$deploy_only" -eq 1 ]]; then
    printf 'Skipping Homebrew profile: %s\n' "${profiles[*]}"
    return 0
  fi

  run_cmd "$repo_root/bootstrap/brew.sh" "${profiles[@]}"
}

profile_packages() {
  run_brew_profile base desktop fonts
}

profile_packages_all() {
  run_brew_profile all
}

profile_gui_path() {
  run_module gui-path
}

# Not in profile_all: zsh.sh repoints ~/.zshenv at this repo. That is opt-in.
profile_shell() {
  run_module zsh
  run_module starship
  run_module kaku
  run_module yazi
  run_module ideavim
}

profile_sublime() {
  run_module sublime
}

profile_desktop() {
  run_module karabiner
  run_module aerospace
  run_module sketchybar
  run_module borders
  run_module hammerspoon
}

# Apps README has always called optional, and which are optional in a way a
# package manager cannot undo: BetterTouchTool stops working after 45 days
# unless you buy it, and Warp is closed source and wants an account. Installing
# either behind `setup.sh all` was the documentation and the behaviour
# disagreeing, so they moved here.
profile_extras() {
  run_module bettertouchtool
  run_module warp
}

profile_ai() {
  run_module ai-router
}

profile_media() {
  run_module mpv
}

profile_app_store() {
  if [[ "$deploy_only" -eq 1 ]]; then
    printf 'Skipping App Store profile in deploy-only mode.\n'
    return 0
  fi
  run_cmd "$repo_root/bootstrap/app-store.sh"
}

# Deploying installs nothing, so this covers every tracked config including the
# layers "all" leaves out. Somebody who opted into the shell layer or the extras
# still gets their config refreshed by a plain `setup.sh deploy`.
profile_deploy() {
  local previous_deploy_only="$deploy_only"
  deploy_only=1
  profile_gui_path
  profile_shell
  profile_sublime
  profile_desktop
  profile_extras
  profile_ai
  profile_media
  deploy_only="$previous_deploy_only"
}

profile_all() {
  profile_packages
  profile_gui_path
  profile_sublime
  profile_desktop
  profile_ai
  profile_media
}

profiles=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-brew)
      no_brew=1
      ;;
    --deploy-only)
      deploy_only=1
      ;;
    --install-only)
      install_only=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      profiles+=("$1")
      ;;
  esac
  shift
done

# Runs after argument parsing so `--help` still works on a machine that has
# nothing installed yet, and before any profile so the failure is one readable
# message instead of a broken half-install. --dry-run only warns: README tells
# strangers to preview first, and that must not require Homebrew.
if [[ "$dry_run" -eq 1 ]]; then
  require_prerequisites warn
else
  require_prerequisites
fi

if [[ "${#profiles[@]}" -eq 0 ]]; then
  profiles=(all)
fi

for profile in "${profiles[@]}"; do
  case "$profile" in
    all)
      profile_all
      ;;
    packages)
      profile_packages
      ;;
    packages-all)
      profile_packages_all
      ;;
    gui-path)
      profile_gui_path
      ;;
    shell)
      profile_shell
      ;;
    sublime)
      profile_sublime
      ;;
    desktop)
      profile_desktop
      ;;
    extras)
      profile_extras
      ;;
    ai)
      profile_ai
      ;;
    media)
      profile_media
      ;;
    app-store)
      profile_app_store
      ;;
    deploy)
      profile_deploy
      ;;
    *)
      printf 'Unknown setup profile: %s\n\n' "$profile" >&2
      usage >&2
      exit 1
      ;;
  esac
done

report_skipped_modules

if ! report_failed_steps; then
  exit 1
fi
