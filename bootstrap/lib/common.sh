#!/usr/bin/env bash
set -euo pipefail

repo_root_dir() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "$script_dir"
}

# Fail fast on a missing toolchain. Without this the first module script to need
# Homebrew dies with a bare `command not found`, several screens into an install
# the user cannot tell apart from a real bug.
# Pass "warn" to report problems without failing. --dry-run uses that: previewing
# is the one thing a stranger should be able to do before installing anything,
# including Homebrew itself.
require_prerequisites() {
  local mode="${1:-fail}"

  if [[ "${DOTFILES_SKIP_PREFLIGHT:-0}" == "1" ]]; then
    return 0
  fi

  local -a problems
  local problem
  problems=()

  if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
    problems+=('Xcode Command Line Tools are missing. Install them: xcode-select --install')
  fi

  if ! command -v git >/dev/null 2>&1; then
    problems+=('git is missing. It ships with the Xcode Command Line Tools, or: brew install git')
  fi

  if ! command -v brew >/dev/null 2>&1; then
    problems+=('Homebrew is missing. Install it from https://brew.sh, then open a new shell so brew is on PATH.')
  fi

  if [[ "${#problems[@]}" -eq 0 ]]; then
    return 0
  fi

  if [[ "$mode" == "warn" ]]; then
    printf 'Note: prerequisites are missing. This preview still works, but installing will not.\n\n' >&2
  else
    printf 'Cannot bootstrap: missing prerequisites.\n\n' >&2
  fi

  for problem in ${problems[@]+"${problems[@]}"}; do
    printf '  - %s\n' "$problem" >&2
  done
  printf '\nSee the Prerequisites section of README.md.\n' >&2

  if [[ "$mode" == "warn" ]]; then
    printf '\n' >&2
    return 0
  fi

  printf 'Set DOTFILES_SKIP_PREFLIGHT=1 to bypass this check.\n' >&2
  return 1
}

DOTFILES_INSTALL=1
DOTFILES_DEPLOY=1
DOTFILES_BREW=1

install_flag_usage() {
  cat <<'EOF'
Common install flags:
  --install-only   Install packages/external dependencies only; do not deploy config.
  --deploy-only    Deploy config only; skip Homebrew/package installation.
  --no-brew        Skip Homebrew commands but still run non-brew setup steps.
  --no-deploy      Skip config deployment.
  -h, --help       Show this help.
EOF
}

parse_install_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --install-only)
        DOTFILES_INSTALL=1
        DOTFILES_DEPLOY=0
        ;;
      --deploy-only)
        DOTFILES_INSTALL=0
        DOTFILES_DEPLOY=1
        DOTFILES_BREW=0
        ;;
      --no-brew)
        DOTFILES_BREW=0
        ;;
      --no-deploy)
        DOTFILES_DEPLOY=0
        ;;
      -h|--help)
        install_flag_usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        install_flag_usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

should_install() {
  [[ "$DOTFILES_INSTALL" -eq 1 ]]
}

should_deploy() {
  [[ "$DOTFILES_DEPLOY" -eq 1 ]]
}

should_brew() {
  [[ "$DOTFILES_BREW" -eq 1 ]]
}

ensure_brew_tap() {
  local tap="$1"
  should_brew || return 0
  if ! brew tap | grep -Fx "$tap" >/dev/null 2>&1; then
    brew tap "$tap"
  fi
}

brew_install() {
  should_brew || return 0
  brew install "$@"
}

cask_app_paths() {
  local cask="$1"
  local token="${cask##*/}"
  local info

  info="$(brew info --cask "$cask" 2>/dev/null || true)"
  printf '%s\n' "$info" | awk '
    /^==> Artifacts/ { in_artifacts = 1; next }
    /^==>/ { in_artifacts = 0 }
    in_artifacts && /\.app \(App\)/ {
      sub(/^[[:space:]]*/, "")
      sub(/ \(App\).*/, "")
      print
    }
  '

  case "$token" in
    aerospace)
      printf '%s\n' "AeroSpace.app"
      ;;
    bettertouchtool)
      printf '%s\n' "BetterTouchTool.app"
      ;;
    hammerspoon)
      printf '%s\n' "Hammerspoon.app"
      ;;
    karabiner-elements)
      printf '%s\n' "Karabiner-Elements.app"
      ;;
    mpv)
      printf '%s\n' "mpv.app"
      ;;
    warp)
      printf '%s\n' "Warp.app"
      ;;
  esac
}

cask_app_exists() {
  local cask="$1"
  local app

  while IFS= read -r app; do
    [[ -n "$app" ]] || continue
    if [[ -d "/Applications/$app" || -d "$HOME/Applications/$app" || -d "/Applications/Utilities/$app" ]]; then
      return 0
    fi
  done < <(cask_app_paths "$cask" | sort -u)

  return 1
}

brew_install_cask() {
  should_brew || return 0

  local cask token
  for cask in "$@"; do
    token="${cask##*/}"

    if brew list --cask --versions "$cask" >/dev/null 2>&1 || brew list --cask --versions "$token" >/dev/null 2>&1; then
      printf 'Cask already managed by Homebrew: %s\n' "$cask"
      continue
    fi

    if cask_app_exists "$cask"; then
      printf 'Cask app already exists outside Homebrew; skipping install: %s\n' "$cask"
      continue
    fi

    brew install --cask "$cask"
  done
}

require_repo_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf 'Missing required path: %s\n' "$path" >&2
    exit 1
  fi
}

ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

backup_target() {
  local target="$1"
  local stamp="$2"
  local backup_path suffix

  [[ -e "$target" || -L "$target" ]] || return 0

  backup_path="${target}.backup_${stamp}"
  suffix=1
  while [[ -e "$backup_path" || -L "$backup_path" ]]; do
    backup_path="${target}.backup_${stamp}_${suffix}"
    suffix=$((suffix + 1))
  done

  mv "$target" "$backup_path"
  printf 'Backed up %s -> %s\n' "$target" "$backup_path"
}

paths_match() {
  local source_path="$1"
  local target="$2"

  [[ -e "$target" || -L "$target" ]] || return 1

  if [[ -d "$source_path" && -d "$target" && ! -L "$target" ]]; then
    diff -qr "$source_path" "$target" >/dev/null 2>&1
    return $?
  fi

  if [[ -f "$source_path" && -f "$target" && ! -L "$target" ]]; then
    cmp -s "$source_path" "$target"
    return $?
  fi

  return 1
}

deploy_repo_path() {
  local repo_root="$1"
  local source_rel="$2"
  local target="$3"
  local stamp="$4"
  local source_path="$repo_root/$source_rel"

  require_repo_path "$source_path"
  ensure_parent_dir "$target"

  if paths_match "$source_path" "$target"; then
    printf 'Unchanged: %s\n' "$target"
    return 0
  fi

  backup_target "$target" "$stamp"

  if [[ -d "$source_path" ]]; then
    cp -R "$source_path" "$target"
  else
    cp "$source_path" "$target"
  fi

  printf 'Deployed: %s -> %s\n' "$source_rel" "$target"
}
