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

# Keep the ledger inside the sandbox: sourcing the library means deploys from
# this test would otherwise write into the developer's own state directory.
export XDG_STATE_HOME="$tmp_dir/state"

mkdir -p "$tmp_dir/repo/source"
printf 'one\n' >"$tmp_dir/repo/source/file.txt"

deploy_repo_path "$tmp_dir/repo" "source" "$tmp_dir/target" "smoke" >/dev/null
deploy_repo_path "$tmp_dir/repo" "source" "$tmp_dir/target" "smoke" >/dev/null

if compgen -G "$tmp_dir/target/*.backup_*" >/dev/null; then
  printf 'deploy_repo_path created a backup for unchanged content\n' >&2
  exit 1
fi

printf 'local change\n' >"$tmp_dir/target/file.txt"
deploy_repo_path "$tmp_dir/repo" "source" "$tmp_dir/target" "smoke" >/dev/null

# The repo copy has not moved, so the local change is the newer one and stays.
if [[ "$(cat "$tmp_dir/target/file.txt")" != 'local change' ]]; then
  printf 'deploy_repo_path overwrote a local change the repo had not changed\n' >&2
  exit 1
fi

# A real upstream change does get deployed, and the local version is backed up
# next to the file that changed. Moving the whole directory aside is what used
# to throw away everything else the user kept in it, so both halves are
# asserted: the file backup exists, the directory backup does not.
printf 'two\n' >"$tmp_dir/repo/source/file.txt"
deploy_repo_path "$tmp_dir/repo" "source" "$tmp_dir/target" "smoke" >/dev/null

if ! compgen -G "$tmp_dir/target/file.txt.backup_*" >/dev/null; then
  printf 'deploy_repo_path did not backup changed content\n' >&2
  exit 1
fi

if compgen -G "$tmp_dir/target.backup_*" >/dev/null; then
  printf 'deploy_repo_path moved the whole target directory aside\n' >&2
  exit 1
fi

if [[ ! -s "$tmp_dir/state/ai-first-dotfiles/backups.tsv" ]]; then
  printf 'deploy_repo_path did not record anything in the backup ledger\n' >&2
  exit 1
fi
