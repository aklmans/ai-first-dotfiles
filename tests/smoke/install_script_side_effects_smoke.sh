#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# A missing rg makes the assertions below pass vacuously instead of failing.
if ! command -v rg >/dev/null 2>&1; then
  printf 'ripgrep (rg) is required by this smoke test: brew install ripgrep\n' >&2
  exit 1
fi

! rg -n '(>>|tee\s+-a).*(\.zshenv|\.zprofile|\.zshrc)|printf .*>>.*(\.zshenv|\.zprofile|\.zshrc)' \
  "$repo_root/bootstrap"

! rg -n 'homebrew/cask-fonts' "$repo_root/bootstrap"
! rg -n 'qlcolorcode|qlstephen|quicklook-json|quicklookase|webpquicklook|homebrew/services|homebrew-services' "$repo_root/bootstrap"
! rg -n 'brew install .*([^/:[:alnum:]_-]|^)gup([^/[:alnum:]_-]|$)' "$repo_root/bootstrap/brew.sh"
if rg -n 'brew install --cask' "$repo_root/bootstrap/brew.sh"; then
  printf 'bootstrap/brew.sh must route casks through brew_install_cask\n' >&2
  exit 1
fi
rg -n 'ensure_brew_tap nao1215/tap' "$repo_root/bootstrap/brew.sh" >/dev/null
rg -n 'nao1215/tap/gup' "$repo_root/bootstrap/brew.sh" >/dev/null

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

source "$repo_root/bootstrap/lib/common.sh"

mkdir -p "$tmp_dir/repo/source"
printf 'one\n' >"$tmp_dir/repo/source/file.txt"

deploy_repo_path "$tmp_dir/repo" "source" "$tmp_dir/target" "smoke" >/dev/null
deploy_repo_path "$tmp_dir/repo" "source" "$tmp_dir/target" "smoke" >/dev/null

if compgen -G "$tmp_dir/target.backup_*" >/dev/null; then
  printf 'deploy_repo_path created a backup for unchanged content\n' >&2
  exit 1
fi

printf 'local change\n' >"$tmp_dir/target/file.txt"
deploy_repo_path "$tmp_dir/repo" "source" "$tmp_dir/target" "smoke" >/dev/null

if ! compgen -G "$tmp_dir/target.backup_*" >/dev/null; then
  printf 'deploy_repo_path did not backup changed content\n' >&2
  exit 1
fi
